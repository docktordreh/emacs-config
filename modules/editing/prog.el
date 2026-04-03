;;; modules/editing/prog.el -*- lexical-binding: t; -*-
;; Generic programming niceties.

(add-hook! 'prog-mode-hook #'rainbow-delimiters-mode)
(add-hook! 'prog-mode-hook #'highlight-numbers-mode)

(use-package! indent-bars
  :config
  ;; Don’t draw guides behind docstrings.
  (setq indent-bars-exclude-faces '(font-lock-doc-face)))


