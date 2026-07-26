;;; system/my-exwm-config.el -*- lexical-binding: t; -*-

(require 'exwm)
(require 'cl-lib)
(require 'evil)

(setq exwm-workspace-number 5)
(add-hook 'exwm-update-class-hook
          (lambda () (exwm-workspace-rename-buffer exwm-class-name)))

(defun my-exwm-start-process (name program &rest args)
  "Start PROGRAM unless its EXWM session process is already running."
  (let ((executable (executable-find program)))
    (when (and executable (not (process-live-p (get-process name))))
      (let ((process (apply #'start-process name nil executable args)))
        (set-process-query-on-exit-flag process nil)))))

(defun my-exwm-start-session-programs ()
  "Start notification, authentication, tray, and clipboard utilities."
  (make-directory (expand-file-name "parcellite" (or (getenv "XDG_DATA_HOME")
                                                     "~/.local/share")) t)
  (my-exwm-start-process "dunst" "dunst")
  (my-exwm-start-process "polkit-mate-agent"
                         "/usr/libexec/polkit-mate-authentication-agent-1")
  (my-exwm-start-process "nm-applet" "nm-applet")
  (my-exwm-start-process "blueman-applet" "blueman-applet")
  (my-exwm-start-process "parcellite" "parcellite"))


;; EXWM only sends these keys to Emacs in line mode when they are prefixes.
;; Keep Doom's Evil leader and window commands ahead of the focused X client.
(dolist (key '(32 ?\C-w))
  (cl-pushnew key exwm-input-prefix-keys))
(evil-set-initial-state 'exwm-mode 'normal)

(setq exwm-input-global-keys
      `(([?\s-r] . exwm-reset)
        ([?\s-w] . exwm-workspace-switch)
        (,(kbd "s-d") . (lambda ()
                          (interactive)
                          (my-exwm-start-process "session-launcher" "session-action" "launcher")))
        (,(kbd "<print>") . (lambda ()
                              (interactive)
                              (my-exwm-start-process "session-screenshot" "session-action" "screenshot")))
        (,(kbd "s-S") . (lambda ()
                          (interactive)
                          (my-exwm-start-process "session-screenshot" "session-action" "screenshot")))
        (,(kbd "M-X") . (lambda ()
                          (interactive)
                          (my-exwm-start-process "session-lock" "session-action" "lock")))
        (,(kbd "<XF86AudioPlay>") . (lambda ()
                                      (interactive)
                                      (my-exwm-start-process "playerctl-play" "playerctl" "play-pause")))
        (,(kbd "<XF86AudioNext>") . (lambda ()
                                      (interactive)
                                      (my-exwm-start-process "playerctl-next" "playerctl" "next")))
        (,(kbd "<XF86AudioPrev>") . (lambda ()
                                      (interactive)
                                      (my-exwm-start-process "playerctl-previous" "playerctl" "previous")))
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
(add-hook 'exwm-init-hook #'my-exwm-start-session-programs 90)
(exwm-wm-mode)
