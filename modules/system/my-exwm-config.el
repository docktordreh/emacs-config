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
        (,(kbd "<escape>") . my-exwm-double-escape)
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
(setq exwm-systemtray-height 36
      exwm-systemtray-icon-gap 6)
(exwm-systemtray-mode 1)
(setq exwm-input-line-mode-passthrough t)

(evil-set-initial-state 'exwm-mode 'normal)

(defcustom my-exwm-double-escape-delay 0.25
  "Maximum delay between two Escape presses."
  :type 'number)

(defvar-local my-exwm-pending-escape-timer nil)

;; Prevent the Evil hook and EXWM hook from recursively triggering
;; one another while we deliberately update both states.
(defvar-local my-exwm--syncing nil)

(defun my-exwm--typing-state-p ()
  "Return non-nil when Evil is in an application-typing state."
  (memq evil-state '(insert replace)))

(defun my-exwm-cancel-pending-escape ()
  "Cancel a delayed Escape for the current EXWM buffer."
  (when (timerp my-exwm-pending-escape-timer)
    (cancel-timer my-exwm-pending-escape-timer))
  (setq my-exwm-pending-escape-timer nil))

(defun my-exwm--sync-from-evil ()
  "Make EXWM's selected input mode follow the current Evil state."
  (when (and (derived-mode-p 'exwm-mode)
             exwm--id
             (not my-exwm--syncing))
    (let ((my-exwm--syncing t))
      (if (my-exwm--typing-state-p)
          ;; Do not check `exwm--input-mode' here.  It may temporarily be
          ;; line-mode while a minibuffer or echo-area interaction is active.
          (unless (eq exwm--selected-input-mode 'char-mode)
            (exwm-input-release-keyboard exwm--id))

        ;; Every non-typing Evil state belongs to EXWM line mode.
        (my-exwm-cancel-pending-escape)
        (unless (eq exwm--selected-input-mode 'line-mode)
          (exwm-input-grab-keyboard exwm--id))))))

(defun my-exwm--sync-from-exwm ()
  "Make Evil follow EXWM's persistent selected input mode."
  (when (and (derived-mode-p 'exwm-mode)
             (not my-exwm--syncing))
    (let ((my-exwm--syncing t))
      (pcase exwm--selected-input-mode
        ('char-mode
         (unless (my-exwm--typing-state-p)
           (evil-insert-state)))

        ('line-mode
         (my-exwm-cancel-pending-escape)
         (when (my-exwm--typing-state-p)
           (evil-normal-state)))))))

(defun my-exwm-enter-insert ()
  "Enter Evil insert state and EXWM char mode atomically."
  (interactive)
  (when (and (derived-mode-p 'exwm-mode)
             exwm--id)
    (let ((my-exwm--syncing t))
      (evil-insert-state)
      (exwm-input-release-keyboard exwm--id))))

(defun my-exwm-enter-normal ()
  "Enter Evil normal state and EXWM line mode atomically."
  (interactive)
  (when (and (derived-mode-p 'exwm-mode)
             exwm--id)
    (my-exwm-cancel-pending-escape)
    (let ((my-exwm--syncing t))
      ;; Grab first so Emacs owns the keyboard before normal state starts.
      (exwm-input-grab-keyboard exwm--id)
      (evil-normal-state))))

(defun my-exwm--replay-pending-escape (buffer)
  "Send one delayed Escape to the X client in BUFFER."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq my-exwm-pending-escape-timer nil)

      ;; Do not replay a stale Escape after leaving insert/char mode.
      (when (and (derived-mode-p 'exwm-mode)
                 (my-exwm--typing-state-p)
                 (eq exwm--selected-input-mode 'char-mode))
        (when-let ((window (get-buffer-window buffer t)))
          (with-selected-window window
            (exwm-input--fake-key
             (aref (kbd "<escape>") 0))))))))

(defun my-exwm-double-escape ()
  "Delay one Escape; double Escape returns to normal/line mode."
  (interactive)

  ;; Repair any pre-existing mismatch before interpreting Escape.
  (when (derived-mode-p 'exwm-mode)
    (my-exwm--sync-from-evil))

  (cond
   ((and (derived-mode-p 'exwm-mode)
         (my-exwm--typing-state-p))
    (if (timerp my-exwm-pending-escape-timer)
        ;; Second Escape: neither Escape reaches the application.
        (my-exwm-enter-normal)

      ;; First Escape: stay in insert/char mode. Send it to the
      ;; application only when the timeout expires.
      (let ((buffer (current-buffer)))
        (setq my-exwm-pending-escape-timer
              (run-at-time
               my-exwm-double-escape-delay
               nil
               #'my-exwm--replay-pending-escape
               buffer)))))

   ((derived-mode-p 'exwm-mode)
    ;; Also repairs the inverse mismatch: normal state plus char mode.
    (my-exwm-enter-normal))

   (t
    (keyboard-escape-quit))))

(defun my-exwm-evil-sync-setup ()
  "Install bidirectional Evil/EXWM synchronization in this X buffer."
  (dolist (hook '(evil-normal-state-entry-hook
                  evil-insert-state-entry-hook
                  evil-replace-state-entry-hook
                  evil-visual-state-entry-hook
                  evil-motion-state-entry-hook
                  evil-operator-state-entry-hook
                  evil-emacs-state-entry-hook))
    (add-hook hook #'my-exwm--sync-from-evil nil t))

  (add-hook 'exwm-input-input-mode-change-hook
            #'my-exwm--sync-from-exwm nil t)

  (my-exwm-enter-normal))

(add-hook 'exwm-mode-hook #'my-exwm-evil-sync-setup)

(evil-define-key '(insert replace) exwm-mode-map
  (kbd "<escape>") #'my-exwm-double-escape)
(add-hook 'exwm-init-hook #'my-exwm-start-session-programs 90)
(exwm-wm-mode)
