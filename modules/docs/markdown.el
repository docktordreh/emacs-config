;;; modules/docs/markdown.el -*- lexical-binding: t; -*-
;; Markdown editing on top of Doom's :lang markdown.  Markup stays visible:
;; no header scaling, markup hiding or URL hiding.

(after! markdown-mode
  (add-to-list 'auto-mode-alist '("\\.mdx\\'" . astro-ts-mode))
  (setq markdown-asymmetric-header t                      ; "# Title", not "# Title #"
        markdown-indent-on-enter 'indent-and-new-item     ; RET continues lists
        markdown-list-indent-width 2)                     ; Prettier-compatible nesting
  ;; Fence labels without a matching `<lang>-mode' function.
  (dolist (lang '(("tf" . terraform-mode)
                  ("yml" . yaml-mode)))
    (add-to-list 'markdown-code-lang-modes lang)))

;; `astro-ts-mode' derives from `html-ts-mode', which makes Apheleia select
;; `prettier-html'. Prettier then collapses prose newlines in MDX pages.  So
;; the mode has no default formatter; buffers choose one themselves: remark
;; (below) or their language server (`(format +lsp)').
(after! apheleia
  (add-to-list 'apheleia-mode-alist '(astro-ts-mode))
  (setf (alist-get 'remark apheleia-formatters)
        '("apheleia-npx" "remark" "--quiet" "--frail" "--file-path" filepath)))

(defun dd/docs-use-remark-h ()
  "Format Markdown and MDX with remark in projects with a remark config.
Runs before lsp-mode connects, so `+format-with-lsp-mode' keeps remark."
  (when (and buffer-file-name
             (string-match-p "\\.mdx?\\'" buffer-file-name)
             (locate-dominating-file
              buffer-file-name
              (lambda (dir) (directory-files dir nil "\\`\\.remarkrc"))))
    (setq-local +format-with 'remark)))

(add-hook 'markdown-mode-hook #'dd/docs-use-remark-h)
(add-hook 'astro-ts-mode-hook #'dd/docs-use-remark-h)

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

(defun dd/astro--frontmatter-for-language (language)
  "Return current buffer's front matter with LANGUAGE set."
  (save-excursion
    (goto-char (point-min))
    (unless (looking-at-p "---[ \t]*$")
      (user-error "Current document has no YAML front matter"))
    (forward-line 1)
    (unless (re-search-forward "^---[ \t]*$" nil t)
      (user-error "Current document has no closing front matter delimiter"))
    (let ((header (buffer-substring-no-properties (point-min) (match-end 0))))
      (if (string-match-p "^language:[ \t]*" header)
          (replace-regexp-in-string
           "^language:[ \t]*.*$"
           (format "language: %s" language)
           header)
        (let ((closing (string-match "^---[ \t]*$" header 4)))
          (unless closing
            (user-error "Current document has no closing front matter delimiter"))
          (concat (substring header 0 closing)
                  (format "language: %s\n" language)
                  (substring header closing)))))))

(defun dd/astro-open-translation ()
  "Open or create the English or German counterpart of the current document."
  (interactive)
  (unless (derived-mode-p 'astro-ts-mode)
    (user-error "Current buffer is not an Astro document"))
  (unless buffer-file-name
    (user-error "Current buffer has no file"))
  (let* ((project-root (locate-dominating-file
                        buffer-file-name
                        (lambda (dir)
                          (file-directory-p (expand-file-name "docs" dir)))))
         (docs-root (and project-root (expand-file-name "docs/" project-root)))
         (relative (and docs-root (file-relative-name buffer-file-name docs-root)))
         (german-p (and relative (string-prefix-p "de/" relative)))
         (language (if german-p "en" "de"))
         (translation (and relative
                           (expand-file-name
                            (if german-p
                                (substring relative 3)
                              (concat "de/" relative))
                            docs-root))))
    (unless (and docs-root translation)
      (user-error "Current document is not under a docs directory"))
    (unless (file-exists-p translation)
      (unless (y-or-n-p (format "Create translation %s? " translation))
        (user-error "Translation not found for %s" buffer-file-name))
      (make-directory (file-name-directory translation) t)
      (let ((frontmatter (dd/astro--frontmatter-for-language language)))
        (with-temp-file translation
          (insert frontmatter)
          (insert "\n\n"))))
    (find-file-other-window translation)))

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

(after! astro-ts-mode
  (map! :map astro-ts-mode-map
        :localleader
        :desc "Open translation" "t" #'dd/astro-open-translation))
