;;; modules/docs/vale.el -*- lexical-binding: t; -*-
;; Vale owns documentation style and terminology.  Rules come from the
;; repository's own .vale.ini; nothing runs without one.

(use-package! vale-mode
  :mode ("\\.vaf\\'" . vale-mode))

(defcustom dd/docs-vale-config-files '(".vale.ini" "_vale.ini" "vale.ini" ".vale" "_vale")
  "Vale configuration file names, in Vale's own lookup order."
  :type '(repeat string)
  :group 'dd/docs)

(defun dd/docs-vale-config-file (&optional dir)
  "Return the nearest Vale configuration file above DIR."
  (when-let* ((parent (locate-dominating-file
                       (or dir default-directory)
                       (lambda (parent)
                         (seq-some (lambda (name) (file-regular-p (expand-file-name name parent)))
                                   dd/docs-vale-config-files)))))
    (seq-find #'file-regular-p
              (mapcar (lambda (name) (expand-file-name name parent)) dd/docs-vale-config-files))))

(defun dd/docs-vale-config-dir (&optional dir)
  "Return the directory holding the nearest Vale configuration above DIR."
  (when-let* ((file (dd/docs-vale-config-file dir)))
    (file-name-directory file)))

(defvar dd/docs--vale-path-support nil
  "Cache of (EXECUTABLE . SUPPORTS-PATH-P) for `dd/docs-vale--supports-path-p'.")

(defun dd/docs-vale--supports-path-p ()
  "Return non-nil if the installed Vale understands --path (3.15+)."
  (when-let* ((vale (executable-find "vale")))
    (unless (equal (car dd/docs--vale-path-support) vale)
      (setq dd/docs--vale-path-support
            (cons vale (with-temp-buffer
                         (call-process vale nil t nil "--help")
                         (goto-char (point-min))
                         (and (search-forward "--path" nil t) t)))))
    (cdr dd/docs--vale-path-support)))

(defun dd/docs-vale--args ()
  "Vale arguments for the current buffer.
Vale matches .vale.ini sections against the path relative to the config
directory, so the file is named that way.  Vale 3.15+ lints the unsaved
buffer from stdin via --path; older versions lint the saved file."
  (let ((file (file-relative-name buffer-file-name (dd/docs-vale-config-dir))))
    (append
     ;; LTeX+ owns spelling while it is attached; CI still runs Vale.Spelling.
     (when (dd/docs--ltex-attached-p)
       (list "--filter=.Name != \"Vale.Spelling\""))
     (if (dd/docs-vale--supports-path-p)
         (list (concat "--path=" file))
       (list file)))))

(defun dd/docs-vale--fix (line span action suggestions)
  "Build a Flycheck fix from a Vale replacement ACTION."
  (when (and (equal action "replace")
             (consp suggestions))
    (flycheck-fix-new
     :description (format "Replace with '%s'" (car suggestions))
     :edits (list
             (flycheck-fix-edit-new
              :line line
              :column (car span)
              :end-line line
              :end-column (1+ (cadr span))
              :replacement (car suggestions))))))

(defun dd/docs-vale--parse (output checker buffer)
  "Parse Vale's JSON OUTPUT into Flycheck errors for CHECKER in BUFFER."
  (let ((report (ignore-errors
                   (json-parse-string output :object-type 'alist :array-type 'list))))
    (cl-loop
     for (_file . alerts) in report
     when (consp alerts)                ; skip Vale's own error object
     append (mapcar
             (lambda (alert)
               (let-alist alert
                 (flycheck-error-new-at
                  .Line (car .Span)
                  (pcase .Severity ("error" 'error) ("warning" 'warning) (_ 'info))
                  .Message
                  :id .Check :checker checker :buffer buffer
                  :filename (buffer-file-name buffer)
                  :end-line .Line :end-column (1+ (cadr .Span))
                  :fix (dd/docs-vale--fix .Line .Span .Action.Name .Suggestions))))
             alerts))))

(after! flycheck
  (flycheck-define-checker vale
    "Prose linter driven by the repository's .vale.ini."
    :command ("vale" "--output=JSON" "--no-exit" (eval (dd/docs-vale--args)))
    :standard-input t
    :working-directory (lambda (_checker) (dd/docs-vale-config-dir))
    :error-parser dd/docs-vale--parse
    :modes (markdown-mode gfm-mode dd/mdx-mode astro-ts-mode)
    :predicate (lambda ()
                 (and (bound-and-true-p dd/technical-writing-mode)
                      buffer-file-name
                      (dd/docs-vale-config-dir)
                      (or (dd/docs-vale--supports-path-p)
                          (flycheck-buffer-saved-p)))))
  (add-to-list 'flycheck-checkers 'vale))

(defun dd/docs-vale-chain-after-lsp-h ()
  "Run Vale after the `lsp' checker so both sets of diagnostics show up."
  (when (and (flycheck-valid-checker-p 'lsp)
             (flycheck-valid-checker-p 'vale)
             (not (memq 'vale (get 'lsp 'flycheck-next-checkers))))
    (flycheck-add-next-checker 'lsp 'vale t)))

(add-hook 'lsp-diagnostics-mode-hook #'dd/docs-vale-chain-after-lsp-h)

;; Flycheck ignores `flycheck-buffer' while a check runs.  With async Vale
;; chained after `lsp', LTeX+ results arriving mid-run would be dropped until
;; the next edit, so queue that request and replay it when the run ends.
(defvar-local dd/docs--flycheck-pending nil)

(defun dd/docs--flycheck-queue-a (fn &rest args)
  "Queue FN (`flycheck-buffer') if a check is running in a writing buffer."
  (if (and (bound-and-true-p dd/technical-writing-mode)
           (bound-and-true-p flycheck-mode)
           (flycheck-running-p))
      (setq dd/docs--flycheck-pending t)
    (apply fn args)))

(defun dd/docs--flycheck-replay-h ()
  "Re-run a check that was requested during the previous one."
  (when dd/docs--flycheck-pending
    (setq dd/docs--flycheck-pending nil)
    (run-at-time 0 nil (lambda (buffer)
                         (when (buffer-live-p buffer)
                           (with-current-buffer buffer (flycheck-buffer))))
                 (current-buffer))))

(advice-add 'flycheck-buffer :around #'dd/docs--flycheck-queue-a)
(add-hook 'flycheck-after-syntax-check-hook #'dd/docs--flycheck-replay-h)

(defun dd/docs-vale--compile (target)
  "Run Vale on TARGET (relative to the config directory) in a compilation buffer."
  (unless (executable-find "vale")
    (user-error "vale is not installed (https://vale.sh/docs/install)"))
  (let ((default-directory (or (dd/docs-vale-config-dir)
                               (user-error "No .vale.ini above %s" default-directory))))
    (compilation-start (concat "vale --output=line " (shell-quote-argument (funcall target)))
                       nil (lambda (_) "*vale*"))))

(defun dd/docs-vale-file ()
  "Save and run Vale on the current file."
  (interactive)
  (unless buffer-file-name
    (user-error "Buffer is not visiting a file"))
  (when (buffer-modified-p)
    (save-buffer))
  (let ((file buffer-file-name))
    (dd/docs-vale--compile (lambda () (file-relative-name file)))))

(defun dd/docs-vale-project ()
  "Run Vale on everything its configuration covers."
  (interactive)
  (dd/docs-vale--compile (lambda () ".")))

(map! :leader
      (:prefix "D"                ; declared in writing-mode.el
       :desc "Vale: this file" "v" #'dd/docs-vale-file
       :desc "Vale: project"   "V" #'dd/docs-vale-project))
