;;; system/my-exwm-config.el -*- lexical-binding: t; -*-

(require 'exwm)
(setq exwm-workspace-number 4)
(add-hook 'exwm-update-class-hook
          (lambda() (exwm-workspace-rename-buffer exwm-class-name)))

(setq exwm-input-global-keys
      `(([?\s-r] . exwm-reset)
        ([?\s-w] . exwm-workspace-switch)
        ([?\s-&] . (lambda (cmd)
                     (interactive (list (read-shell-command "$ ")))
                     (start-process-shell-command cmd nil cmd)))
        ,@(mapcar (lambda (i)
                    `(,(kbd (format "s-%d" i)) .
                      (lambda ()
                        (interactive)
                        (exwm-workspace-switch-create ,i))))
                  (number-sequence 0 9))))
(require 'exwm-systemtray)
(exwm-systemtray-mode 1)
(require 'exwm-randr)
(setq exwm-randr-workspace-output-plist '(1 "eDP-1" 2 "DP-4-8"))
(add-hook 'exwm-randr-screen-change-hook
          (lambda ()
            (start-process-shell-command
             "xrandr" nil "xrandr --output eDP-1 --mode 2256x1504 --pos 0x658 --rotate normal --output DP-1 --off --output DP-2 --off --output DP-3 --off --output DP-4 --off --output DP-4-8 --primary --mode 3840x2160 --pos 2256x0 --rotate normal --output DP-4-1 --off")))
(exwm-randr-mode)
(exwm-wm-mode)

