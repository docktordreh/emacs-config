;;; modules/projects/receiver.el -*- lexical-binding: t; -*-

(defconst dd/receiver-directory
  (expand-file-name "Projects/receiver" (getenv "HOME")))

(defconst dd/receiver-emacs-directory
  (expand-file-name "Projects/receiver-emacs" (getenv "HOME")))

(defun dd/receiver-load ()
  "Load the local Receiver client when its checkout is available."
  (when (file-directory-p dd/receiver-emacs-directory)
    (add-to-list 'load-path dd/receiver-emacs-directory)
    (when (require 'receiver-emacs nil t)
      (let ((binary (expand-file-name "target/debug/receiver" dd/receiver-directory)))
        (when (file-executable-p binary)
          (setq receiver-emacs-program binary))))))

(dd/receiver-load)
