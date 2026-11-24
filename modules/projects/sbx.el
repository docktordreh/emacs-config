;;; modules/projects/sbx.el -*- lexical-binding: t; -*-

(require 'subr-x)

(defconst dd/sbx-directory
  (expand-file-name "Projects/github-personal/sbx.el" (getenv "HOME")))

(defconst dd/sbx-repository
  "git@github.com:docktordreh/sbx.el.git")

(defun dd/sbx-load ()
  "Load sbx.el when its local checkout is available."
  (when (file-directory-p dd/sbx-directory)
    (add-to-list 'load-path dd/sbx-directory)
    (require 'sbx nil t)))

(defun dd/sbx-ensure-checkout ()
  "Offer to clone and load sbx.el when its checkout is missing."
  (unless (or (featurep 'sbx)
              (dd/sbx-load))
    (when (and (executable-find "git")
               (y-or-n-p "sbx.el is not checked out. Clone it? "))
      (make-directory (file-name-directory dd/sbx-directory) t)
      (with-temp-buffer
        (if (zerop (process-file "git" nil (current-buffer) nil "clone"
                                 dd/sbx-repository dd/sbx-directory))
            (if (dd/sbx-load)
                (message "sbx.el cloned and loaded")
              (message "sbx.el was cloned but could not be loaded"))
          (message "Could not clone sbx.el: %s"
                   (string-trim (buffer-string))))))))

(dd/sbx-load)
(add-hook 'emacs-startup-hook #'dd/sbx-ensure-checkout)
