;;; modules/docs/markdown.el -*- lexical-binding: t; -*-
;; Markdown editing on top of Doom's :lang markdown.  Markup stays visible:
;; no header scaling, markup hiding or URL hiding.

(after! markdown-mode
  (setq markdown-asymmetric-header t                      ; "# Title", not "# Title #"
        markdown-indent-on-enter 'indent-and-new-item     ; RET continues lists
        markdown-list-indent-width 2)                     ; Prettier-compatible nesting
  ;; Fence labels without a matching `<lang>-mode' function.
  (dolist (lang '(("tf" . terraform-mode)
                  ("yml" . yaml-mode)))
    (add-to-list 'markdown-code-lang-modes lang)))

;; `global-org-pretty-table-mode' (modules/org/ux.el) would draw Markdown table
;; pipes as box characters; keep tables as typed.
(defun dd/docs--not-markdown-p (&rest _)
  "Return non-nil outside Markdown buffers."
  (not (derived-mode-p 'markdown-mode)))

(advice-add 'turn-on-org-pretty-table-mode :before-while #'dd/docs--not-markdown-p)

(defun dd/docs-edit-frontmatter ()
  "Edit the YAML front matter in an indirect `yaml-mode' buffer."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (unless (looking-at-p "---[ \t]*$")
      (user-error "No YAML front matter at the top of this buffer"))
    (forward-line 1)
    (let ((beg (point)))
      (unless (re-search-forward "^---[ \t]*$" nil t)
        (user-error "Front matter has no closing ---"))
      (let ((edit-indirect-guess-mode-function (lambda (&rest _) (yaml-mode))))
        (edit-indirect-region beg (match-beginning 0) t)))))

(map! :after markdown-mode
      :map markdown-mode-map
      :localleader
      :desc "Edit front matter"        "y" #'dd/docs-edit-frontmatter
      :desc "Technical-writing mode"   "w" #'dd/technical-writing-mode
      (:prefix ("T" . "table")
       :desc "Align"                   "a" #'markdown-table-align
       :desc "Insert row"              "r" #'markdown-table-insert-row
       :desc "Delete row"              "R" #'markdown-table-delete-row
       :desc "Insert column"           "c" #'markdown-table-insert-column
       :desc "Delete column"           "C" #'markdown-table-delete-column
       :desc "Sort lines"              "s" #'markdown-table-sort-lines
       :desc "Transpose"               "t" #'markdown-table-transpose
       :desc "Region to table"         "x" #'markdown-table-convert-region))
