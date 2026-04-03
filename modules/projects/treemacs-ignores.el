;;; modules/projects/treemacs-ignores.el -*- lexical-binding: t; -*-
;; Treemacs ignore predicates + LaTeX build junk ignore lists.

(after! treemacs
  (defvar treemacs-file-ignore-extensions '()
    "Extensions ignored by `dd/treemacs-ignore-filter`.")
  (defvar treemacs-file-ignore-globs '()
    "Glob patterns ignored by `dd/treemacs-ignore-filter`.")
  (defvar treemacs-file-ignore-regexps '()
    "Regexps derived from `treemacs-file-ignore-globs`.")

  (defun dd/treemacs-ignore-generate-regexps ()
    (setq treemacs-file-ignore-regexps
          (mapcar #'dired-glob-regexp treemacs-file-ignore-globs)))

  (defun dd/treemacs-ignore-filter (_file full-path)
    (or (member (file-name-extension full-path) treemacs-file-ignore-extensions)
        (seq-some (lambda (re) (string-match-p re full-path))
                  treemacs-file-ignore-regexps)))

  (add-to-list 'treemacs-ignored-file-predicates #'dd/treemacs-ignore-filter))

(setq treemacs-file-ignore-extensions
      '("aux" "bbl" "blg" "log" "out" "pdf" "synctex.gz" "gz" "toc" "fdb_latexmk" "fls"
        "glg" "glo" "gls" "glsdefs" "ist" "acn" "acr" "alg"
        "mw" "pdfa.xmpi"))

(setq treemacs-file-ignore-globs
      '("*/_minted-*"
        "*/.auctex-auto"
        "*/_region_.log"
        "*/_region_.tex"
        "*/.TeX-auto-save"
        "*/.TeX-save"))

(after! treemacs
  (dd/treemacs-ignore-generate-regexps))


