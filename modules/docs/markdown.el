;;; modules/docs/markdown.el -*- lexical-binding: t; -*-
;; Markdown editing on top of Doom's :lang markdown.  Heading colors and
;; sizes come from the theme, so `markdown-header-scaling' stays off.

(after! markdown-mode
  (setq markdown-asymmetric-header t                      ; "# Title", not "# Title #"
        markdown-indent-on-enter 'indent-and-new-item     ; RET continues lists
        markdown-list-indent-width 2)                     ; Prettier-compatible nesting
  ;; Fence labels without a matching `<lang>-mode' function.
  (dolist (lang '(("tf" . terraform-mode)
                  ("yml" . yaml-mode)))
    (add-to-list 'markdown-code-lang-modes lang)))

;;; MDX

;; MDX is Markdown plus ESM, {expressions} and JSX.  `gfm-mode' fontifies the
;; Markdown and, via `markdown-enable-html', component tags as inline HTML.
(define-derived-mode dd/mdx-mode gfm-mode "MDX"
  "Major mode for MDX documents: GitHub Flavored Markdown with ESM and JSX.")

(add-to-list 'auto-mode-alist '("\\.mdx\\'" . dd/mdx-mode))

(font-lock-add-keywords
 'dd/mdx-mode
 '(("^\\(?:import\\|export\\)\\_>.*$" 0 'font-lock-preprocessor-face t)
   ("{/\\*.*?\\*/}" 0 'font-lock-comment-face t)))

;; MDX has no indented code blocks, but formatters indent component children,
;; which markdown-mode would show as code.
(defun dd/mdx--skip-pre-blocks-a (&rest _)
  "Return non-nil in MDX buffers, so indented text is not code."
  (derived-mode-p 'dd/mdx-mode))

(advice-add 'markdown-syntax-propertize-pre-blocks :before-until #'dd/mdx--skip-pre-blocks-a)

;;; In-place preview

(defface dd/mdx-preview-frontmatter-face '((t nil))
  "Background face for the YAML frontmatter in MDX preview."
  :group 'markdown-faces)

(defface dd/mdx-preview-frontmatter-delimiter-face '((t nil))
  "Face for the YAML frontmatter boundary markers in MDX preview."
  :group 'markdown-faces)

(defface dd/mdx-preview-source-face '((t nil))
  "Background face for imports and fallback face for JSX components."
  :group 'markdown-faces)

(defface dd/mdx-preview-depth-1-face '((t :inherit dd/mdx-preview-source-face))
  "Background face for the first JSX nesting color."
  :group 'markdown-faces)

(defface dd/mdx-preview-depth-2-face '((t :inherit dd/mdx-preview-source-face))
  "Background face for the second JSX nesting color."
  :group 'markdown-faces)

(defface dd/mdx-preview-depth-3-face '((t :inherit dd/mdx-preview-source-face))
  "Background face for the third JSX nesting color."
  :group 'markdown-faces)

(defface dd/mdx-preview-depth-4-face '((t :inherit dd/mdx-preview-source-face))
  "Background face for the fourth JSX nesting color."
  :group 'markdown-faces)

(defface dd/mdx-preview-depth-5-face '((t :inherit dd/mdx-preview-source-face))
  "Background face for the fifth JSX nesting color."
  :group 'markdown-faces)

(defconst dd/mdx-preview--depth-faces
  [dd/mdx-preview-depth-1-face dd/mdx-preview-depth-2-face
   dd/mdx-preview-depth-3-face dd/mdx-preview-depth-4-face
   dd/mdx-preview-depth-5-face])

(defconst dd/mdx-preview--parser
  (expand-file-name "ltex-mdx/preview.mjs" (file-name-directory load-file-name)))

(defvar-local dd/mdx-preview--process nil)
(defvar-local dd/mdx-preview--restore-indent-bars nil)

(defvar-local dd/mdx-preview--line nil
  "Marker at the beginning of the line whose source markup is visible.")

(defun dd/mdx-preview--heading (limit)
  "Find an ATX heading before LIMIT whose markup should be hidden."
  (catch 'match
    (while (markdown-match-propertized-text 'markdown-heading limit)
      (when (and (match-beginning 4)
                 (not (= (match-beginning 0) dd/mdx-preview--line)))
        (throw 'match t)))))

(defun dd/mdx-preview--hide-heading ()
  "Hide the matched heading's hash markers without changing its face."
  (dolist (group '(4 6))
    (when (match-beginning group)
      (put-text-property (match-beginning group) (match-end group) 'display "")))
  nil)

(defun dd/mdx-preview--active-line-p (position)
  "Return non-nil if POSITION is on the line showing source."
  (save-excursion
    (goto-char position)
    (= (line-beginning-position) dd/mdx-preview--line)))

(defun dd/mdx-preview--frontmatter-marker (icon)
  "Display ICON in place of the matched YAML fence off the current line."
  (unless (dd/mdx-preview--active-line-p (match-beginning 0))
    (put-text-property (match-beginning 0) (match-end 0) 'display icon))
  'dd/mdx-preview-frontmatter-delimiter-face)

(defun dd/mdx-preview--inline-markup (limit)
  "Match Markdown delimiters already identified by font-lock before LIMIT."
  (catch 'match
    (while (< (point) limit)
      (let* ((beg (point))
             (end (min (line-beginning-position 2)
                       (next-single-property-change beg 'invisible nil limit))))
        (goto-char end)
        (when (and (eq (get-text-property beg 'invisible) 'markdown-markup)
                   (not (dd/mdx-preview--active-line-p beg))
                   (not (markdown-code-block-at-point-p beg)))
          (set-match-data (list beg end))
          (throw 'match t))))))

(defconst dd/mdx-preview--keywords
  '((dd/mdx-preview--heading (4 (dd/mdx-preview--hide-heading)))
    (markdown-match-yaml-metadata-begin (0 (dd/mdx-preview--frontmatter-marker "»") prepend))
    (markdown-match-yaml-metadata-end (0 (dd/mdx-preview--frontmatter-marker "«") prepend))
    ((lambda (limit) (markdown-match-propertized-text 'markdown-yaml-metadata-section limit))
     (0 'dd/mdx-preview-frontmatter-face append))
    (dd/mdx-preview--inline-markup
     (0 (progn (put-text-property (match-beginning 0) (match-end 0) 'display "") nil)))))

(defun dd/docs--background-ranges (ranges)
  "Convert parser line and column RANGES to rainbow-backgrounds ranges."
  (save-excursion
    (save-restriction
      (widen)
      (let ((lines (save-excursion
                     (goto-char (point-min))
                     (vconcat (cons (point) (cl-loop while (search-forward "\n" nil t)
                                                      collect (point)))))))
        (mapcar
         (pcase-lambda (`(,kind ,start ,column ,end ,end-column ,depth))
           (list (+ (aref lines (1- start)) column)
                 (+ (aref lines (1- end)) end-column)
                 depth
                 (pcase kind ("inline" 'inline) ((or "yaml" "esm") 'full))
                 (pcase kind ("yaml" 'dd/mdx-preview-frontmatter-face)
                             ("esm" 'dd/mdx-preview-source-face))))
         ranges)))))

(defun dd/docs--embedded-html-ranges (ranges)
  "Parse the raw HTML RANGES together, excluding Markdown text and code."
  (let* ((source (buffer-substring-no-properties (point-min) (point-max)))
         (html (replace-regexp-in-string "[^\n]" " " source))
         elements)
    (pcase-dolist (`(,beg ,end . ,_) ranges)
      (store-substring html (1- beg) (substring source (1- beg) (1- end))))
    (when ranges
      (with-temp-buffer
        (insert html)
        (rainbow-backgrounds-html (lambda (parsed) (setq elements parsed)))))
    ;; Decide whether elements are inline from the original Markdown text.
    (mapcar (pcase-lambda (`(,beg ,end ,depth . ,_))
              (rainbow-backgrounds-element beg end depth))
            elements)))

(defun dd/docs-markdown-backgrounds (emit)
  "Parse the current Markdown or MDX buffer and pass its ranges to EMIT."
  (when (and (executable-find "node")
             (file-directory-p (expand-file-name "node_modules"
                                                 (file-name-directory dd/mdx-preview--parser))))
    (let* ((buffer (current-buffer))
           (mdx (derived-mode-p 'dd/mdx-mode))
           (tick (buffer-chars-modified-tick))
           (output (generate-new-buffer " *Markdown backgrounds*")))
      (when (process-live-p dd/mdx-preview--process)
        (delete-process dd/mdx-preview--process))
      (setq dd/mdx-preview--process
            (make-process
             :name "markdown-backgrounds" :buffer output :noquery t :connection-type 'pipe
             :coding 'utf-8-unix
             :command (append (list "node" dd/mdx-preview--parser)
                              (unless mdx '("--markdown")))
             :sentinel
             (lambda (process _event)
               (when (memq (process-status process) '(exit signal))
                 (unwind-protect
                     (when (and (zerop (process-exit-status process))
                                (buffer-live-p buffer))
                       (let ((ranges (with-current-buffer output
                                       (goto-char (point-min))
                                       (json-parse-buffer :array-type 'list))))
                         (with-current-buffer buffer
                           (when (= tick (buffer-chars-modified-tick))
                             (save-restriction
                               (widen)
                               (let ((regions (dd/docs--background-ranges ranges)))
                                 (funcall emit (if mdx regions
                                                 (dd/docs--embedded-html-ranges regions)))))))))
                   (kill-buffer output))))))
      (process-send-region dd/mdx-preview--process (point-min) (point-max))
      (process-send-eof dd/mdx-preview--process))))

(defun dd/docs-enable-rainbow-backgrounds-h ()
  (setq-local rainbow-backgrounds-provider #'dd/docs-markdown-backgrounds))

(add-hook 'markdown-mode-hook #'dd/docs-enable-rainbow-backgrounds-h)

(defun dd/mdx-preview--restore-indent-bars ()
  (when dd/mdx-preview--restore-indent-bars
    (indent-bars-mode 1)
    (setq dd/mdx-preview--restore-indent-bars nil)))

(defun dd/mdx-preview--flush-line (position)
  "Refontify the line at POSITION, if accessible."
  (when (<= (point-min) position (point-max))
    (save-excursion
      (goto-char position)
      (font-lock-flush (line-beginning-position) (line-beginning-position 2)))))

(defun dd/mdx-preview--reveal ()
  "Reveal source markup on the current line and render it on the old line."
  (let ((line (line-beginning-position))
        (old (marker-position dd/mdx-preview--line)))
    (unless (= line old)
      (set-marker dd/mdx-preview--line line)
      (dd/mdx-preview--flush-line old)
      (dd/mdx-preview--flush-line line))))

(define-minor-mode dd/mdx-preview-mode
  "Preview MDX headings in place and shade frontmatter and component source."
  :lighter " MDX-P"
  (when (and dd/mdx-preview-mode (not (derived-mode-p 'dd/mdx-mode)))
    (setq dd/mdx-preview-mode nil)
    (user-error "MDX preview is only available in MDX buffers"))
  (if dd/mdx-preview-mode
      (progn
        (when (bound-and-true-p indent-bars-mode)
          (setq dd/mdx-preview--restore-indent-bars t)
          (indent-bars-mode -1))
        (setq dd/mdx-preview--line (copy-marker (line-beginning-position)))
        (font-lock-add-keywords nil dd/mdx-preview--keywords 'append)
        (add-hook 'post-command-hook #'dd/mdx-preview--reveal nil t)
        (add-hook 'change-major-mode-hook #'dd/mdx-preview--restore-indent-bars nil t))
    (remove-hook 'post-command-hook #'dd/mdx-preview--reveal t)
    (remove-hook 'change-major-mode-hook #'dd/mdx-preview--restore-indent-bars t)
    (dd/mdx-preview--restore-indent-bars)
    (font-lock-remove-keywords nil dd/mdx-preview--keywords)
    (when dd/mdx-preview--line
      (set-marker dd/mdx-preview--line nil))
    (setq dd/mdx-preview--line nil))
  (font-lock-flush))

(map! :map dd/mdx-mode-map
      :localleader
      :desc "Toggle in-place preview" "V" #'dd/mdx-preview-mode)

;;; Site links

;; In Astro/Starlight content, links starting with / are site routes
;; ("/platform/x/" -> <content dir>/platform/x.mdx), not filesystem paths.
;; markdown-mode would open /platform/x/ from the filesystem root, and the
;; MDX language server resolves and completes them against the repository
;; root.  Relative links (images) resolve against the file, as markdown-mode
;; already does.

(defcustom dd/docs-content-dirs '("src/content/docs/" "docs/")
  "Directories, relative to a project root, that the site serves at /."
  :type '(repeat string)
  :group 'dd/docs)

(defun dd/docs-content-root (&optional file)
  "Return the content directory serving the site that FILE belongs to."
  (when-let* ((file (or file buffer-file-name)))
    (cl-loop for dir in dd/docs-content-dirs
             for root = (locate-dominating-file file dir)
             for content = (and root (expand-file-name dir root))
             when (and content (file-in-directory-p file content))
             return content)))

(defun dd/docs--route-path (route)
  "Return ROUTE without anchor, query and surrounding slashes."
  (string-trim (url-unhex-string (car (split-string route "[#?]"))) "/" "/"))

(defun dd/docs--path-file (path root)
  "Return the page or file for the slash-less route PATH under ROOT."
  (or (cl-loop for base in (if (string-empty-p path) '("index") (list path (concat path "/index")))
               thereis (cl-loop for ext in '(".mdx" ".md")
                                for file = (expand-file-name (concat base ext) root)
                                thereis (and (file-regular-p file) file)))
      (let ((file (expand-file-name path root)))
        (and (not (string-empty-p path)) (file-regular-p file) file))
      ;; Pages whose front matter sets `slug:'.
      (when-let* ((rg (executable-find "rg")))
        (car (ignore-errors
               (process-lines rg "-l" "--glob" "*.{md,mdx}"
                              (format "^slug:[ \t]*[\"']?/?%s/?[\"']?[ \t]*$" (regexp-quote path))
                              root))))))

(defun dd/docs-route-file (route root)
  "Return the file under content dir ROOT that serves the site ROUTE.
Routes are lowercase, and a locale route without a translation
(\"/de/x/\") serves the default-locale page (\"/x/\"), as in Starlight."
  (let* ((path (dd/docs--route-path route))
         (paths (delete-dups (list path (downcase path)))))
    (or (cl-loop for p in paths thereis (dd/docs--path-file p root))
        (cl-loop for p in paths
                 when (string-match "\\`[a-z][a-z]\\(?:-[a-z]+\\)?/" p)
                 thereis (and (file-directory-p (expand-file-name (match-string 0 p) root))
                              (dd/docs--path-file (substring p (match-end 0)) root))))))

(defun dd/docs--heading-slug (heading)
  "Return the anchor Starlight generates for HEADING (github-slugger)."
  (replace-regexp-in-string
   " " "-" (replace-regexp-in-string "[^[:alnum:] _-]" "" (downcase (string-trim heading)))))

(defun dd/docs--goto-anchor (route)
  "Move to the heading that ROUTE's #anchor names, if any."
  (when-let* ((anchor (cadr (split-string route "#"))))
    (let ((pos (save-excursion
                 (goto-char (point-min))
                 (cl-loop while (re-search-forward "^[ \t]*#+[ \t]+\\(.+?\\)[ \t#]*$" nil t)
                          when (equal (dd/docs--heading-slug (match-string-no-properties 1)) anchor)
                          return (line-beginning-position)))))
      (if pos (goto-char pos) (message "No heading for #%s" anchor)))))

(defun dd/docs-follow-route (url)
  "Open the page for the site route URL in a docs project.
Return nil for other links, so markdown-mode handles them."
  (when-let* (((string-prefix-p "/" url))
              ((not (string-prefix-p "//" url)))
              (root (dd/docs-content-root)))
    (let ((file (or (dd/docs-route-file url root)
                    (user-error "No page for %s in %s" url (abbreviate-file-name root)))))
      (find-file file)
      (dd/docs--goto-anchor url)
      t)))

(add-hook 'markdown-follow-link-functions #'dd/docs-follow-route)

(defun dd/docs--href-at-point ()
  "Return the root-relative href=\"/...\" value at point, if any."
  (let ((pos (point)))
    (save-excursion
      (goto-char (line-beginning-position))
      (cl-loop while (re-search-forward "href={?[\"']\\(/[^\"']*\\)" (line-end-position) t)
               when (<= (match-beginning 0) pos (match-end 0))
               return (match-string-no-properties 1)))))

(defun dd/docs-follow-link-at-point ()
  "Follow the link at point; site routes in href=\"/...\" too."
  (interactive)
  (if-let* ((href (dd/docs--href-at-point)))
      (dd/docs-follow-route href)
    (markdown-follow-thing-at-point nil)))

(set-lookup-handlers! 'dd/mdx-mode :file '(dd/docs-follow-link-at-point :async t))

(defvar dd/docs--routes-cache (make-hash-table :test #'equal)
  "Content dir -> (TIME . ROUTES).")

(defun dd/docs--routes (root)
  "Return the site routes of the pages under content dir ROOT (cached 60 s)."
  (let ((cached (gethash root dd/docs--routes-cache)))
    (if (and cached (< (float-time (time-since (car cached))) 60))
        (cdr cached)
      (let ((routes (cl-loop for file in (directory-files-recursively root "\\.mdx?\\'")
                             for route = (replace-regexp-in-string
                                          "\\(?:\\`\\|/\\)index\\'" ""
                                          (file-name-sans-extension (file-relative-name file root)))
                             collect (if (string-empty-p route) "/" (concat "/" route "/")))))
        (puthash root (cons (current-time) routes) dd/docs--routes-cache)
        routes))))

(defun dd/docs-route-capf ()
  "Complete site routes after \"](/\" and \"href=\\\"/\" in docs projects."
  (when-let* ((root (dd/docs-content-root))
              ((looking-back "\\(?:](\\|href={?[\"']\\)\\(/[^] \t\n)\"']*\\)" (line-beginning-position))))
    (list (match-beginning 1) (point) (dd/docs--routes root) :exclusive 'no)))

(defun dd/docs-route-capf-h ()
  "Put `dd/docs-route-capf' first in Markdown buffers.
lsp-mode pushes `lsp-completion-at-point' to the front with `add-to-list',
which ignores hook depth, so this runs again when LSP completion starts."
  (when (derived-mode-p 'markdown-mode)
    (remove-hook 'completion-at-point-functions #'dd/docs-route-capf t)
    (add-hook 'completion-at-point-functions #'dd/docs-route-capf -50 t)))

(add-hook 'markdown-mode-hook #'dd/docs-route-capf-h)
(add-hook 'lsp-completion-mode-hook #'dd/docs-route-capf-h)

;; The MDX server's document links point into the repository root.
(setq-hook! 'dd/mdx-mode-hook lsp-enable-links nil)

;; Apheleia's default for Markdown modes is Prettier, which only knows MDX 1
;; and joins lists nested in components.  `astro-ts-mode' derives from
;; `html-ts-mode' and would get `prettier-html'.  Neither mode has a default
;; formatter; buffers choose one themselves: remark (below) or their language
;; server (`(format +lsp)').
(after! apheleia
  (add-to-list 'apheleia-mode-alist '(dd/mdx-mode))
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
  (unless (derived-mode-p 'markdown-mode 'astro-ts-mode)
    (user-error "Current buffer is not a Markdown, MDX or Astro document"))
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
      ;; "t" is Doom's toggle prefix here.
      :desc "Open translation"         "L" #'dd/astro-open-translation
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
