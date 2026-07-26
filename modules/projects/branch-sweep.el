;;; modules/projects/branch-sweep.el -*- lexical-binding: t; -*-

(let ((directory (expand-file-name "Projects/active/magit-link-sync" (getenv "HOME"))))
  (when (file-directory-p directory)
    (add-to-list 'load-path directory)
    (require 'branch-sweep nil t)))
