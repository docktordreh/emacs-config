;;; modules/projects/dired.el -*- lexical-binding: t; -*-
;; Dired defaults.

(after! dired
  (add-hook 'dired-mode-hook #'dired-hide-details-mode))
