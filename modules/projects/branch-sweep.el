;;; modules/projects/branch-sweep.el -*- lexical-binding: t; -*-

(require 'subr-x)

(defconst dd/branch-sweep-directory
  (expand-file-name "Projects/active/magit-link-sync" (getenv "HOME")))

(defconst dd/branch-sweep-repository
  "git@github.com:docktordreh/branch-sweep.git")

(defun dd/branch-sweep-load ()
  "Load Branch Sweep when its local checkout is available."
  (when (file-directory-p dd/branch-sweep-directory)
    (add-to-list 'load-path dd/branch-sweep-directory)
    (require 'branch-sweep nil t)))

(defun dd/branch-sweep-ensure-checkout ()
  "Offer to clone and load Branch Sweep when its checkout is missing."
  (unless (or (featurep 'branch-sweep)
              (dd/branch-sweep-load))
    (when (and (executable-find "git")
               (y-or-n-p "Branch Sweep is not checked out. Clone it? "))
      (make-directory (file-name-directory dd/branch-sweep-directory) t)
      (with-temp-buffer
        (if (zerop (process-file "git" nil (current-buffer) nil "clone"
                                 dd/branch-sweep-repository dd/branch-sweep-directory))
            (if (dd/branch-sweep-load)
                (message "Branch Sweep cloned and loaded")
              (message "Branch Sweep was cloned but could not be loaded"))
          (message "Could not clone Branch Sweep: %s" (string-trim (buffer-string))))))))

(dd/branch-sweep-load)
(add-hook 'emacs-startup-hook #'dd/branch-sweep-ensure-checkout)
