;;; modules/projects/az-pr-sync.el -*- lexical-binding: t; -*-

(require 'subr-x)

(defconst dd/az-pr-sync-directory
  (expand-file-name "Projects/active/az-pr-sync" (getenv "HOME")))

(defconst dd/az-pr-sync-repository
  "git@github.com:docktordreh/az-pr-sync.git")

(defun dd/az-pr-sync-load ()
  "Load Azure PR Sync when its local checkout is available."
  (when (file-directory-p dd/az-pr-sync-directory)
    (add-to-list 'load-path dd/az-pr-sync-directory)
    (require 'forge-azure nil t)))

(defun dd/az-pr-sync-ensure-checkout ()
  "Offer to clone and load Azure PR Sync when its checkout is missing."
  (unless (or (featurep 'forge-azure)
              (dd/az-pr-sync-load))
    (when (and (executable-find "git")
               (y-or-n-p "Azure PR Sync is not checked out. Clone it? "))
      (make-directory (file-name-directory dd/az-pr-sync-directory) t)
      (with-temp-buffer
        (if (zerop (process-file "git" nil (current-buffer) nil "clone"
                                 dd/az-pr-sync-repository dd/az-pr-sync-directory))
            (if (dd/az-pr-sync-load)
                (message "Azure PR Sync cloned and loaded")
              (message "Azure PR Sync was cloned but could not be loaded"))
          (message "Could not clone Azure PR Sync: %s"
                   (string-trim (buffer-string))))))))

(dd/az-pr-sync-load)
(add-hook 'emacs-startup-hook #'dd/az-pr-sync-ensure-checkout)
