;;; modules/docs/writing-mode.el -*- lexical-binding: t; -*-
;; `dd/technical-writing-mode': prose tooling for Markdown in docs-as-code
;; repositories.  The other modules/docs/* files hook into this mode.

(defgroup dd/docs nil
  "Docs-as-code writing environment."
  :group 'text)

(defcustom dd/docs-auto-enable t
  "Enable `dd/technical-writing-mode' in Markdown files of documentation projects."
  :type 'boolean
  :group 'dd/docs)

(defcustom dd/docs-project-markers
  '(".vale.ini" "_vale.ini" "vale.ini" ".marksman.toml")
  "Files whose presence in a parent directory marks a documentation project."
  :type '(repeat string)
  :group 'dd/docs)

(defcustom dd/docs-centered-width 100
  "Text width used by `dd/docs-toggle-centered'."
  :type 'integer
  :group 'dd/docs)

(defcustom dd/docs-todo-regexp "\\b(TODO|FIXME|XXX|TBD)\\b"
  "Ripgrep pattern used by `dd/docs-find-todos'."
  :type 'string
  :group 'dd/docs)

(defun dd/docs-root (&optional dir)
  "Return the nearest parent of DIR containing one of `dd/docs-project-markers'."
  (locate-dominating-file
   (or dir default-directory)
   (lambda (parent)
     (seq-some (lambda (marker) (file-exists-p (expand-file-name marker parent)))
               dd/docs-project-markers))))

(defun dd/docs-search-root ()
  "Return the documentation root, falling back to the project root."
  (or (dd/docs-root) (doom-project-root) default-directory))

(define-minor-mode dd/technical-writing-mode
  "Prose tooling for technical documentation.

Enables Vale and LTeX+ diagnostics and highlights TODO markers in prose.
Markdown source, code blocks and links stay untouched; Doom already
soft-wraps text buffers with `visual-line-mode'."
  :lighter " Docs"
  :group 'dd/docs
  (if dd/technical-writing-mode
      ;; Doom limits hl-todo to comments in text modes; drafts carry TODOs in prose.
      (setq-local hl-todo-text-modes '(markdown-mode))
    (kill-local-variable 'hl-todo-text-modes))
  (font-lock-flush)
  (when (bound-and-true-p flycheck-mode)
    (flycheck-buffer)))

(defun dd/docs-maybe-enable-h ()
  "Enable `dd/technical-writing-mode' for local files inside a documentation project."
  (when (and dd/docs-auto-enable
             buffer-file-name
             (not (file-remote-p buffer-file-name))
             (dd/docs-root))
    (dd/technical-writing-mode +1)))

(add-hook 'markdown-mode-hook #'dd/docs-maybe-enable-h)
(add-hook 'astro-ts-mode-hook #'dd/docs-maybe-enable-h)

(defun dd/docs-toggle-centered ()
  "Toggle a centered text column of `dd/docs-centered-width' characters."
  (interactive)
  (setq-local visual-fill-column-width dd/docs-centered-width
              visual-fill-column-center-text t)
  (visual-fill-column-mode 'toggle))

(defun dd/docs-find-todos ()
  "List TODO/FIXME markers of the documentation project in a `grep-mode' buffer."
  (interactive)
  (let ((default-directory (dd/docs-search-root)))
    (compilation-start
     (concat "rg --no-heading --line-number --color=never -e "
             (shell-quote-argument dd/docs-todo-regexp))
     #'grep-mode)))

(defun dd/docs-search ()
  "Search the documentation project with ripgrep."
  (interactive)
  (consult-ripgrep (dd/docs-search-root)))

(defun dd/docs-find-file ()
  "Find a file in the documentation project."
  (interactive)
  (doom-project-find-file (dd/docs-search-root)))

(defconst dd/docs--init-files
  '((".vale.ini" . "StylesPath = .vale/styles
MinAlertLevel = suggestion
Vocab = Docs

[*.{md,mdx}]
BasedOnStyles = Vale
")
    (".vale/styles/config/vocabularies/Docs/accept.txt" . "")
    (".marksman.toml" . "# Marksman project root; options: https://github.com/artempyanykh/marksman/blob/main/docs/configuration.md
"))
  "Files `dd/docs-init-project' creates, relative to the docs root.
Only Vale's built-in style is enabled; add the project's own styles later.")

(defun dd/docs-init-project (root)
  "Create a minimal Vale and Marksman setup in ROOT, keeping existing files."
  (interactive
   (list (read-directory-name "Docs root: " (or (dd/docs-root) (doom-project-root)) nil t)))
  (let ((has-vale (dd/docs-vale-config-file root))
        created)
    (pcase-dolist (`(,name . ,content) dd/docs--init-files)
      (let ((file (expand-file-name name root)))
        (unless (or (file-exists-p file)
                    ;; Respect _vale.ini, vale.ini, ... and their vocabulary.
                    (and has-vale (string-prefix-p ".vale" name)))
          (make-directory (file-name-directory file) t)
          (write-region content nil file nil 'silent)
          (push name created))))
    (when (and (derived-mode-p 'markdown-mode) buffer-file-name)
      (dd/docs-maybe-enable-h))
    (message (if created
                 (format "Created %s" (string-join (nreverse created) ", "))
               "Vale and Marksman are already set up in %s")
             root)))

(defun dd/docs-install-tools (mermaid)
  "Install marksman, ltex-ls-plus and vale into ~/.local; skip installed ones.
With MERMAID, also install mermaid-cli.  Runs modules/docs/install-tools.sh."
  (interactive (list (y-or-n-p "Also install mermaid-cli (npm) for diagram previews? ")))
  (compilation-start
   (mapconcat #'shell-quote-argument
              `("sh" ,(expand-file-name "modules/docs/install-tools.sh" doom-user-dir)
                ,@(when mermaid '("--mermaid")))
              " ")
   nil (lambda (_) "*docs tools install*")))

(map! :leader
      (:prefix-map ("D" . "docs")
       :desc "Init docs project"      "i" #'dd/docs-init-project
       :desc "Install external tools" "I" #'dd/docs-install-tools
       :desc "Technical-writing mode" "w" #'dd/technical-writing-mode
       :desc "Centered layout"        "c" #'dd/docs-toggle-centered
       :desc "Find doc file"          "f" #'dd/docs-find-file
       :desc "Search docs"            "s" #'dd/docs-search
       :desc "Headings"               "o" #'consult-outline
       :desc "TODO/FIXME list"        "t" #'dd/docs-find-todos
       :desc "Word count"             "n" #'count-words
       :desc "Diagnostics list"       "e" #'flycheck-list-errors))
