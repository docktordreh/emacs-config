;;; modules/editing/prog.el -*- lexical-binding: t; -*-
;; Generic programming niceties.

(add-hook! 'prog-mode-hook #'rainbow-delimiters-mode)
(add-hook! 'prog-mode-hook #'highlight-numbers-mode)

(use-package! indent-bars
  :config
  ;; Don’t draw guides behind docstrings.
  (setq indent-bars-exclude-faces '(font-lock-doc-face))

  (defun +prog/reset-tooltip-stipple ()
    (set-face-attribute 'tooltip nil :stipple nil))

  (add-hook 'indent-bars-mode-hook #'+prog/reset-tooltip-stipple)
  (add-hook 'after-enable-theme-hook #'+prog/reset-tooltip-stipple))

