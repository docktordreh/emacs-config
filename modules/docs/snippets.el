;;; modules/docs/snippets.el -*- lexical-binding: t; -*-
;; Helpers for snippets/markdown-mode.  Projects adapt them two ways:
;;   - .dir-locals.el: `dd/docs-admonition-style' / `dd/docs-admonition-types'
;;   - <project>/.snippets/markdown-mode/*: loaded when a docs buffer opens

(defcustom dd/docs-admonition-style 'directive
  "Callout syntax used by the note/info/warn/danger snippets.
`directive' writes :::note ... ::: (Starlight, remark-directive);
`github' writes > [!NOTE]."
  :type '(choice (const directive) (const github))
  :safe (lambda (value) (memq value '(directive github)))
  :group 'dd/docs)

(defcustom dd/docs-admonition-types nil
  "Alist mapping snippet callout names to the project's names.
Entries override the per-style defaults in `dd/docs--admonition-defaults'."
  :type '(alist :key-type string :value-type string)
  :safe #'listp
  :group 'dd/docs)

(defconst dd/docs--admonition-defaults
  '((directive ("info" . "note") ("warning" . "caution"))
    (github ("danger" . "caution")))
  "Callout names each style lacks, mapped to its closest equivalent.")

(defun dd/docs--admonition-type (type)
  "Return the project's name for callout TYPE."
  (or (cdr (assoc type dd/docs-admonition-types))
      (cdr (assoc type (alist-get dd/docs-admonition-style dd/docs--admonition-defaults)))
      type))

(defun dd/docs-admonition-open (type)
  "Return the opening of a callout of TYPE in `dd/docs-admonition-style'."
  (pcase dd/docs-admonition-style
    ('github (format "> [!%s]\n> " (upcase (dd/docs--admonition-type type))))
    (_ (format ":::%s\n" (dd/docs--admonition-type type)))))

(defun dd/docs-admonition-close ()
  "Return the closing of a callout in `dd/docs-admonition-style'."
  (pcase dd/docs-admonition-style
    ('github "")
    (_ "\n:::")))

(defcustom dd/docs-project-snippets-dir ".snippets"
  "Project directory, found upward from the document, holding yasnippet modes."
  :type 'string
  :group 'dd/docs)

(defvar dd/docs--loaded-snippet-dirs nil
  "Project snippet directories already loaded this session.")

(defun dd/docs-load-project-snippets-h ()
  "Load the project's snippet directory once per session."
  ;; ponytail: yasnippet tables are global, so project snippets stay loaded
  ;; for the session; scope them per project if two repos start to clash.
  (when-let* ((parent (and dd/technical-writing-mode
                           (locate-dominating-file default-directory
                                                   dd/docs-project-snippets-dir)))
              (dir (expand-file-name dd/docs-project-snippets-dir parent)))
    (when (and (file-directory-p dir)
               (not (member dir dd/docs--loaded-snippet-dirs)))
      (push dir dd/docs--loaded-snippet-dirs)
      (with-eval-after-load 'yasnippet
        (yas-load-directory dir t)))))

(add-hook 'dd/technical-writing-mode-hook #'dd/docs-load-project-snippets-h)
