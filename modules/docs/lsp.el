;;; modules/docs/lsp.el -*- lexical-binding: t; -*-
;; Markdown language servers via Doom's lsp-mode (`(markdown +lsp)' in init.el):
;;   Marksman -> links, headings, references, workspace awareness (always)
;;   LTeX+    -> grammar and spelling (only in `dd/technical-writing-mode')
;; MDX (`dd/mdx-mode', see markdown.el):
;;   mdx-analyzer -> MDX/JSX diagnostics, hover, completion (always)
;;   LTeX+        -> as above

(setq-hook! 'markdown-mode-hook
  ;; Stay quiet when a server is missing instead of prompting on every file.
  lsp-enable-suggest-server-download nil
  lsp-warn-no-matched-clients nil
  ;; Marksman and LTeX+ both use full document sync.  lsp-mode's debounce queue
  ;; keeps one pending change per buffer, so only the last server would ever
  ;; see edits (Marksman went stale: no completion for new links).
  lsp-debounce-full-sync-notifications nil)

;;; LTeX+

(defcustom dd/docs-grammar-enabled t
  "Whether LTeX+ checks buffers in `dd/technical-writing-mode'."
  :type 'boolean
  :group 'dd/docs)

(defcustom dd/docs-ltex-user-dictionary
  (expand-file-name "modules/docs/dictionary.txt" doom-user-dir)
  "Word list (one per line) accepted by LTeX+ in every project."
  :type 'file
  :group 'dd/docs)

(defcustom dd/docs-ltex-project-dictionary ".ltex/dictionary.txt"
  "Project word list, looked up in parent directories of the document."
  :type 'string
  :group 'dd/docs)

(defcustom dd/docs-ltex-languages '(("/docs/de/" . "de-DE"))
  "LTeX+ languages by file path: (REGEXP . LANGUAGE).
Files matching no REGEXP use `lsp-ltex-plus-language'."
  :type '(alist :key-type regexp :value-type string)
  :group 'dd/docs)

;; Must be set before lsp-ltex-plus loads; it registers its client from these.
(setq lsp-ltex-plus-active-modes '(markdown-mode gfm-mode dd/mdx-mode)
      lsp-ltex-plus-user-rules-path (file-name-concat doom-data-dir "lsp-ltex-plus/")
      ;; Typography rules that misfire on Markdown source (straight quotes,
      ;; "--" and "->" are deliberate there).
      lsp-ltex-plus-disabled-rules '(:en-US ["EN_QUOTES" "DASH_RULE" "ARROWS"]))

(defun dd/docs--read-words (file)
  "Return the non-empty, non-comment lines of FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (seq-remove (lambda (line) (or (string-empty-p line) (string-prefix-p "#" line)))
                (split-string (buffer-string) "[ \t]*\n" t "[ \t]+"))))

(defun dd/docs--vale-vocabulary-files ()
  "Return the accept.txt files of the Vale vocabularies in scope."
  ;; ponytail: line scan of .vale.ini; parse it properly if Vocab ever needs
  ;; per-section resolution.
  (when-let* ((config (dd/docs-vale-config-file)))
    (with-temp-buffer
      (insert-file-contents config)
      (let ((value (lambda (key)
                     (goto-char (point-min))
                     (when (re-search-forward
                            (format "^[ \t]*%s[ \t]*=[ \t]*\\(.*?\\)[ \t]*$" key) nil t)
                       (match-string 1)))))
        (when-let* ((styles (funcall value "StylesPath"))
                    (vocabs (funcall value "Vocab")))
          (seq-filter
           #'file-readable-p
           (mapcar (lambda (vocab)
                     (expand-file-name (format "config/vocabularies/%s/accept.txt" vocab)
                                       (expand-file-name styles (file-name-directory config))))
                   (split-string vocabs "[ \t]*,[ \t]*" t))))))))

(defun dd/docs--vale-term-expansions (pattern)
  "Return the strings that Vale vocabulary PATTERN matches, or nil.
Vocabulary entries are regexps, but LTeX+ compares dictionary words
literally.  This handles the subset vocabularies use: literals, escapes,
[..] classes, (..|..) groups, `?', top-level `|', and `\\b' and
lookarounds (both dropped).  `.' counts as a literal dot (\"Node.js\").
Other syntax, or more than 64 expansions, returns nil."
  (let ((pos 0) (len (length pattern)))
    (cl-labels
        ((peek () (and (< pos len) (aref pattern pos)))
         (next () (unless (peek) (throw 'unsupported nil)) (prog1 (aref pattern pos) (cl-incf pos)))
         (at (prefix) (string-prefix-p prefix (substring pattern pos)))
         (alternatives ()
           (let ((result (sequence)))
             (while (eq (peek) ?|)
               (next)
               (setq result (append result (sequence))))
             result))
         (sequence ()
           (let ((result (list "")))
             (while (and (peek) (not (memq (peek) '(?| ?\)))))
               (let ((options (term)))
                 (when (eq (peek) ??)
                   (next)
                   (push "" options))
                 (setq result (cl-loop for a in result
                                       nconc (cl-loop for b in options collect (concat a b))))
                 (when (> (length result) 64) (throw 'unsupported nil))))
             result))
         (term ()
           (pcase (next)
             (?\\ (let ((c (next)))
                    (cond ((eq c ?b) (list ""))
                          ((memq c '(?d ?D ?w ?W ?s ?S)) (throw 'unsupported nil))
                          (t (list (string c))))))
             (?\[ (let (chars)
                    (while (not (eq (peek) ?\]))
                      (let ((c (next)))
                        (when (memq c '(?^ ?-)) (throw 'unsupported nil))
                        (push (string c) chars)))
                    (next)
                    (nreverse chars)))
             (?\( (cond ((seq-some #'at '("?!" "?=" "?<!" "?<="))
                         (let ((depth 1))
                           (while (> depth 0)
                             (pcase (next)
                               (?\\ (next))
                               (?\( (cl-incf depth))
                               (?\) (cl-decf depth)))))
                         (list ""))
                        (t (when (at "?:") (setq pos (+ pos 2)))
                           (when (eq (peek) ??) (throw 'unsupported nil))
                           (prog1 (alternatives)
                             (unless (eq (next) ?\)) (throw 'unsupported nil))))))
             ((or ?* ?+ ?{ ?^ ?$) (throw 'unsupported nil))
             (c (list (string c))))))
      (catch 'unsupported
        (prog1 (alternatives)
          (when (peek) (throw 'unsupported nil)))))))

(defvar dd/docs--vale-vocabulary-cache (make-hash-table :test #'equal)
  "Vale vocabulary file -> (MODIFICATION-TIME . WORDS).")

(defun dd/docs--vale-vocabulary-words (file)
  "Return the dictionary words for the Vale vocabulary FILE.
Each entry is expanded with `dd/docs--vale-term-expansions'; multi-word
terms also contribute their single words, since LTeX+ checks words."
  (let ((mtime (file-attribute-modification-time (file-attributes file)))
        (cached (gethash file dd/docs--vale-vocabulary-cache)))
    (if (equal (car cached) mtime)
        (cdr cached)
      (let ((words (delete-dups
                    (cl-loop for entry in (dd/docs--read-words file)
                             nconc (cl-loop for term in (dd/docs--vale-term-expansions entry)
                                            nconc (cons term (split-string term "[ \t/]+" t)))))))
        (puthash file (cons mtime words) dd/docs--vale-vocabulary-cache)
        words))))

(defun dd/docs--ltex-dictionary-files ()
  "Return the readable plain word lists for the current buffer."
  (seq-filter
   #'file-readable-p
   (cons dd/docs-ltex-user-dictionary
         (when-let* ((dir (locate-dominating-file default-directory
                                                  dd/docs-ltex-project-dictionary)))
           (list (expand-file-name dd/docs-ltex-project-dictionary dir))))))

(defun dd/docs-ltex-dictionary ()
  "Value of ltex.dictionary: lsp-ltex-plus' own words, the word-list files
and the project's Vale vocabularies.  Called from the checked document's
buffer (see `dd/docs--configuration-in-scope-buffer-a'), so the project
lookups and `lsp-ltex-plus-language' resolve against that document."
  (lsp-ltex-plus-combine-plists
   lsp-ltex-plus--combined-dictionary
   (list (intern (concat ":" lsp-ltex-plus-language))
         ;; `vconcat' copies: the vocabulary word lists are cached.
         (vconcat (mapcan #'dd/docs--read-words (dd/docs--ltex-dictionary-files))
                  (apply #'append (mapcar #'dd/docs--vale-vocabulary-words
                                          (dd/docs--vale-vocabulary-files)))))))

(defun dd/docs--ltex-environment ()
  "Point JAVA_HOME at the JDK bundled with ltex-ls-plus, if there is one.
Its launcher only falls back to that JDK when JAVA_HOME is empty, so an
older system JAVA_HOME (Java < 21) would otherwise break it."
  (when-let* ((entry (lsp-ltex-plus--server-entry))
              (jdk (car (file-expand-wildcards
                         (expand-file-name "../jdk-*" (file-name-directory (file-truename entry)))))))
    (list (cons "JAVA_HOME" jdk))))

(after! lsp-ltex-plus
  (make-directory lsp-ltex-plus-user-rules-path t)
  ;; Plain `aset': a `setf' on the struct accessor would be macroexpanded when
  ;; this file loads, before lsp-mode defines the struct.
  (aset (gethash 'ltex-ls-plus lsp-clients)
        (cl-struct-slot-offset 'lsp--client 'environment-fn)
        #'dd/docs--ltex-environment)
  (lsp-register-custom-settings '(("ltex.dictionary" dd/docs-ltex-dictionary))))

(defcustom dd/docs-ltex-mdx-proxy
  (expand-file-name "modules/docs/ltex-mdx/proxy.mjs" doom-user-dir)
  "LSP proxy that shows LTeX+ only the Markdown prose of MDX documents.
Used when its node_modules are installed (`npm ci' in its directory)."
  :type 'file
  :group 'dd/docs)

(defun dd/docs--ltex-mdx-proxy-a (command)
  "Run the ltex-ls-plus COMMAND behind `dd/docs-ltex-mdx-proxy'.
LTeX+ reads MDX as CommonMark: it checks import lines and {expressions} as
prose and skips component children.  The proxy masks MDX with remark-mdx."
  (if-let* ((node (executable-find "node"))
            ((file-directory-p (expand-file-name "node_modules"
                                                 (file-name-directory dd/docs-ltex-mdx-proxy)))))
      (append (list node dd/docs-ltex-mdx-proxy) command)
    command))

(after! lsp-ltex-plus
  (advice-add 'lsp-ltex-plus--server-command :filter-return #'dd/docs--ltex-mdx-proxy-a))

(defun dd/docs-ltex-language-h ()
  "Set `lsp-ltex-plus-language' from `dd/docs-ltex-languages'."
  (when-let* ((file buffer-file-name)
              (entry (seq-find (lambda (entry) (string-match-p (car entry) file))
                               dd/docs-ltex-languages)))
    (setq-local lsp-ltex-plus-language (cdr entry))))

(add-hook 'markdown-mode-hook #'dd/docs-ltex-language-h)

(defun dd/docs--configuration-in-scope-buffer-a (fn params)
  "Answer workspace/configuration in the buffer of the requested scopeUri.
lsp-mode ignores scopeUri, so buffer-local settings such as
`lsp-ltex-plus-language' would not reach LTeX+, which asks per document."
  (if-let* ((uri (seq-some #'lsp:configuration-item-scope-uri?
                           (lsp:configuration-params-items params)))
            (buffer (find-buffer-visiting (lsp--uri-to-path uri))))
      (with-current-buffer buffer (funcall fn params))
    (funcall fn params)))

(after! lsp-mode
  (advice-add 'lsp--build-workspace-configuration-response
              :around #'dd/docs--configuration-in-scope-buffer-a))

(defun dd/docs--ltex-wanted-p ()
  "Return non-nil if LTeX+ should check the current buffer."
  (and dd/docs-grammar-enabled
       (bound-and-true-p dd/technical-writing-mode)
       (derived-mode-p 'markdown-mode)))

(defun dd/docs--ltex-attached-p ()
  "Return non-nil if an LTeX+ server manages the current buffer."
  (and (bound-and-true-p lsp-mode)
       (seq-some (lambda (workspace) (eq (lsp--workspace-server-id workspace) 'ltex-ls-plus))
                 (lsp-workspaces))))

(defun dd/docs-ltex-sync-h ()
  "Attach LTeX+ to this buffer exactly when `dd/docs--ltex-wanted-p'."
  (let ((disabled (bound-and-true-p lsp-disabled-clients))) ; lsp-mode may not be loaded yet
    (setq-local lsp-disabled-clients
                (if (dd/docs--ltex-wanted-p)
                    (remq 'ltex-ls-plus disabled)
                  (cl-adjoin 'ltex-ls-plus disabled))))
  (when (and (bound-and-true-p lsp-mode)
             (xor (dd/docs--ltex-wanted-p) (dd/docs--ltex-attached-p)))
    (lsp-disconnect)
    (lsp)))

;; Depth 90: after `dd/docs-maybe-enable-h', before lsp! (local-vars hook).
(add-hook 'markdown-mode-hook #'dd/docs-ltex-sync-h 90)
(add-hook 'dd/technical-writing-mode-hook #'dd/docs-ltex-sync-h)

;;; MDX and Astro

;; Doom runs only the MODE-local-vars-hook of the exact major mode, so its
;; `markdown-mode' hook does not start lsp-mode in `dd/mdx-mode': mdx-analyzer
;; (and LTeX+) for .mdx.  Doom's :lang web has no Astro support: astro-ls.
(add-hook 'dd/mdx-mode-local-vars-hook #'lsp! 'append)
(add-hook 'astro-ts-mode-local-vars-hook #'lsp! 'append)

;; mdx-analyzer asks to watch **/*.mdx.  Docs repos exceed
;; `lsp-file-watch-threshold', so lsp-mode prompts on every start and the
;; server answers nothing until the prompt is answered.  Without the client
;; capability the server does not ask; open buffers still sync via didChange.
(setq-hook! '(dd/mdx-mode-hook astro-ts-mode-hook) lsp-enable-file-watchers nil)

(defun dd/docs--mdx-initialization-options ()
  "Point the MDX language server at the TypeScript installed next to it.
The server refuses to start without typescript.tsdk, and lsp-mdx sends none.
Install it with: npm -g --prefix <lsp-server-install-dir>/npm/@mdx-js/language-server
install typescript@5 (TypeScript 7 has no typescript.js for the server)."
  (list :typescript
        (list :tsdk (expand-file-name "npm/@mdx-js/language-server/lib/node_modules/typescript/lib"
                                      lsp-server-install-dir))))

(after! lsp-mdx
  ;; Plain `aset' for the same reason as for LTeX+ above.
  (aset (gethash 'mdx-analyzer lsp-clients)
        (cl-struct-slot-offset 'lsp--client 'initialization-options)
        #'dd/docs--mdx-initialization-options))

(defun dd/docs-toggle-grammar ()
  "Toggle LTeX+ grammar and spelling checks in all technical-writing buffers."
  (interactive)
  (setq dd/docs-grammar-enabled (not dd/docs-grammar-enabled))
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'markdown-mode)
        (dd/docs-ltex-sync-h))))
  (message "LTeX+ grammar checking %s" (if dd/docs-grammar-enabled "enabled" "disabled")))

(defun dd/docs-add-word-to-project-dictionary (word)
  "Append WORD to the project's `dd/docs-ltex-project-dictionary'."
  (interactive (list (read-string "Accept word in this project: " (thing-at-point 'word t))))
  (let* ((root (or (locate-dominating-file default-directory dd/docs-ltex-project-dictionary)
                   (dd/docs-search-root)))
         (file (expand-file-name dd/docs-ltex-project-dictionary root)))
    (make-directory (file-name-directory file) t)
    (write-region (concat word "\n") nil file 'append)
    (when (dd/docs--ltex-attached-p)
      (lsp--set-configuration (lsp-configuration-section "ltex")))))

(map! :leader
      (:prefix "D"                ; declared in writing-mode.el
       :desc "Toggle grammar (LTeX+)"  "g" #'dd/docs-toggle-grammar
       :desc "Accept word in project"  "d" #'dd/docs-add-word-to-project-dictionary))
