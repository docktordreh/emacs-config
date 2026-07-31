;;; ui/dashboard.el -*- lexical-binding: t; -*-

;;; modules/ui/dashboard.el -*- lexical-binding: t; -*-
;; Splash screen: banner + footer + dashboard widget tweaks.

(load! "dashboard-messages")

(add-hook! 'doom-dashboard-mode-hook
  (lambda ()
    ;; Avoid “background chips” affecting dashboard faces.
    (dolist (face '(font-lock-comment-face
                    font-lock-doc-face
                    font-lock-string-face
                    font-lock-keyword-face))
      (face-remap-add-relative face :background 'unspecified))))

(setq +dashboard-functions '(+dashboard-widget-banner))

(defun my/dashboard--insert-footer ()
  "Insert a centered random footer line."
  (let* ((icon (propertize
                #(" " 0 1 (display (height 1.5)))
                'face `(:foreground ,(doom-color 'magenta))))
         (msg  (nth (random (length my/dashboard-footer-messages))
                    my/dashboard-footer-messages))
         (line (concat icon msg))
         (prefix (propertize
                  " "
                  'display `(space :align-to
                                    (- center ,(/ (float (+dashboard-strlen line)) 2))))))
    (insert prefix line "\n")))

(add-hook! '+dashboard-functions :append
  (my/dashboard--insert-footer)
  (setq mode-line-format nil))

(setq-hook! '+doom-dashboard-mode-hook
  evil-normal-state-cursor (list nil))

(defun my/dashboard-banner-weebery ()
  "Render the custom ASCII banner."
  (let* ((banner '(
                   "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
                   "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⣿⣿⠀⠀⠀⢠⣾⣧⣤⡖⠀⠀⠀⠀⠀⠀⠀"
                   "⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⠋⠀⠉⠀⢄⣸⣿⣿⣿⣿⣿⣥⡤⢶⣿⣦⣀⡀"
                   "⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⡆⠀⠀⠀⣙⣛⣿⣿⣿⣿⡏⠀⠀⣀⣿⣿⣿⡟"
                   "⠀⠀⠀⠀⠀⠀⠀⠀⠙⠻⠷⣦⣤⣤⣬⣽⣿⣿⣿⣿⣿⣿⣿⣟⠛⠿⠋⠀"
                   "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⠋⣿⣿⣿⣿⣿⣿⣿⣿⢿⣿⣿⡆⠀⠀"
                   "⠀⠀⠀⠀⣠⣶⣶⣶⣿⣦⡀⠘⣿⣿⣿⣿⣿⣿⣿⣿⠿⠋⠈⢹⡏⠁⠀⠀"
                   "⠀⠀⠀⢀⣿⡏⠉⠿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡆⠀⢀⣿⡇⠀⠀⠀"
                   "⠀⠀⠀⢸⣿⠀⠀⠀⠀⠀⠙⢿⣿⣿⣿⣿⣿⣿⣿⣿⣟⡘⣿⣿⣃⠀⠀⠀"
                   "⣴⣷⣀⣸⣿⠀⠀⠀⠀⠀⠀⠘⣿⣿⣿⣿⠹⣿⣯⣤⣾⠏⠉⠉⠉⠙⠢⠀"
                   "⠈⠙⢿⣿⡟⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣄⠛⠉⢩⣷⣴⡆⠀⠀⠀⠀⠀"
                   "⠀⠀⠀⠋⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿⣿⣿⣀⡠⠋⠈⢿⣇⠀⠀⠀⠀⠀"
                   "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠿⠿⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀"
                   "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"))
         (longest (apply #'max (mapcar #'length banner))))
    (put-text-property
     (point)
     (dolist (line banner (point))
       (insert (+doom-dashboard--center
                +doom-dashboard--width
                (concat line (make-string (max 0 (- longest (length line))) 32)))
               "\n"))
     'face 'doom-dashboard-banner)))

(setq +dashboard-ascii-banner-fn (lambda () " ")
      +dashboard-anchor '(top . center)
      fancy-splash-image (file-name-concat doom-private-dir "images/logo.svg"))
