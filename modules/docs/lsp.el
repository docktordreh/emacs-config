;;; modules/docs/lsp.el -*- lexical-binding: t; -*-
;; Markdown language servers via Doom's lsp-mode (`(markdown +lsp)' in init.el):
;;   Marksman -> links, headings, references, workspace awareness (always)
;;   LTeX+    -> grammar and spelling (only in `dd/technical-writing-mode')

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

;; Must be set before lsp-ltex-plus loads; it registers its client from these.
(setq lsp-ltex-plus-active-modes '(markdown-mode gfm-mode)
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

(defun dd/docs--ltex-dictionary-files ()
  "Return the readable word lists for the current buffer."
  (seq-filter
   #'file-readable-p
   (append (list dd/docs-ltex-user-dictionary)
           (when-let* ((dir (locate-dominating-file default-directory
                                                    dd/docs-ltex-project-dictionary)))
             (list (expand-file-name dd/docs-ltex-project-dictionary dir)))
           (dd/docs--vale-vocabulary-files))))

(defun dd/docs-ltex-dictionary ()
  "Value of ltex.dictionary: lsp-ltex-plus' own words plus the word-list files.
lsp-mode calls this from a buffer of the requesting workspace, so the
project lookups resolve against that workspace."
  (lsp-ltex-plus-combine-plists
   lsp-ltex-plus--combined-dictionary
   (list (intern (concat ":" lsp-ltex-plus-language))
         (vconcat (mapcan #'dd/docs--read-words (dd/docs--ltex-dictionary-files))))))

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

(defun dd/docs--ltex-wanted-p ()
  "Return non-nil if LTeX+ should check the current buffer."
  (and dd/docs-grammar-enabled (bound-and-true-p dd/technical-writing-mode)))

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
