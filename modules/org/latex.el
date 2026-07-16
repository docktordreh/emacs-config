;;; modules/org/latex.el -*- lexical-binding: t; -*-
;; Org LaTeX export configuration.

(after! ox-latex
  (setq org-latex-pdf-process
        '("latexmk -lualatex -interaction=nonstopmode -file-line-error -synctex=1 %f")))
