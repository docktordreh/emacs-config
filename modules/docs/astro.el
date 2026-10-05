;;; modules/docs/astro.el -*- lexical-binding: t; -*-
;; Astro docs projects: dev server, preview, build and package scripts run in
;; compilation buffers, so errors are navigable with `next-error'.  The
;; project's lockfile decides between pnpm, yarn, bun and npm.

(defcustom dd/astro-config-files
  '("astro.config.mjs" "astro.config.ts" "astro.config.mts" "astro.config.js" "astro.config.cjs")
  "File names that mark the root of an Astro project."
  :type '(repeat string)
  :group 'dd/docs)

(defcustom dd/astro-content-dirs '("src/content/docs/" "src/pages/")
  "Directories, relative to the Astro root, whose files map to URL routes."
  :type '(repeat string)
  :safe #'listp
  :group 'dd/docs)

(defconst dd/astro--lockfiles
  '(("pnpm-lock.yaml" . "pnpm") ("bun.lock" . "bun") ("bun.lockb" . "bun")
    ("yarn.lock" . "yarn") ("package-lock.json" . "npm"))
  "Lockfiles and the package manager that writes them.")

(defun dd/astro-root-p (dir)
  "Return non-nil if DIR contains an Astro config file."
  (seq-some (lambda (file) (file-exists-p (expand-file-name file dir)))
            dd/astro-config-files))

(defun dd/astro-root (&optional dir)
  "Return the nearest Astro project root above DIR."
  (locate-dominating-file (or dir default-directory) #'dd/astro-root-p))

(defun dd/astro--root ()
  "Return the current Astro root or signal a `user-error'."
  (or (dd/astro-root)
      (user-error "No astro.config.* above %s" default-directory)))

(defun dd/astro--package-json (root)
  "Return ROOT's package.json as an alist."
  (let ((file (expand-file-name "package.json" root)))
    (when (file-readable-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (json-parse-buffer :object-type 'alist)))))

(defun dd/astro--scripts (root)
  "Return the script names in ROOT's package.json."
  (mapcar (lambda (script) (symbol-name (car script)))
          (alist-get 'scripts (dd/astro--package-json root))))

(defun dd/astro-package-manager (root)
  "Return the package manager for ROOT.
The nearest lockfile wins (monorepos keep it above ROOT), then the
packageManager field of package.json, then npm."
  (or (when-let* ((dir (locate-dominating-file
                        root (lambda (parent)
                               (seq-some (lambda (lock) (file-exists-p (expand-file-name (car lock) parent)))
                                         dd/astro--lockfiles)))))
        (cdr (seq-find (lambda (lock) (file-exists-p (expand-file-name (car lock) dir)))
                       dd/astro--lockfiles)))
      (when-let* ((spec (alist-get 'packageManager (dd/astro--package-json root))))
        (car (split-string spec "@")))
      "npm"))

(defun dd/astro--script-command (root script)
  "Return the shell command running SCRIPT of ROOT's package.json."
  (unless (member script (dd/astro--scripts root))
    (user-error "package.json has no %s script" script))
  (format "%s run %s" (dd/astro-package-manager root) (shell-quote-argument script)))

(defun dd/astro--dev-command (root)
  "Return the command starting ROOT's dev server."
  (dd/astro--script-command root (if (member "dev" (dd/astro--scripts root)) "dev" "start")))

;;; Compilation buffers

(defvar-local dd/astro--url nil
  "Local URL reported by the dev server in this buffer.")

(defvar-local dd/astro--pending-route nil
  "Route to open once the dev server in this buffer reports its URL.")

(defun dd/astro--url-for (url route)
  "Join the dev server URL with ROUTE."
  (concat (string-remove-suffix "/" url) "/" route))

(defun dd/astro--detect-url-h ()
  "Remember the dev server's Local URL and open a pending preview."
  (unless dd/astro--url
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward "Local[^h\n]*\\(https?://[^ \t\n\e]+\\)" nil t)
        (setq dd/astro--url (match-string-no-properties 1))
        (when dd/astro--pending-route
          (browse-url (dd/astro--url-for dd/astro--url dd/astro--pending-route))
          (setq dd/astro--pending-route nil))))))

(after! compile
  (dolist (entry
           '(;; "  Location:\n    /abs/src/content/docs/page.md:12:3", Vite's "  File: ..."
             (astro-location "^[ \t]+\\(?:File: \\)?\\(/[^ \t\n:]+\\):\\([0-9]+\\):\\([0-9]+\\)" 1 2 3)
             ;; dev server: "[ERROR] [loader] Failed to reload guides/page.md: ..."
             ;; (relative to a content dir, see `compilation-search-path' below)
             (astro-reload "\\[ERROR\\] \\[[^]\n]+\\] Failed to reload \\([^ :\n]+\\):" 1)
             ;; astro check: "src/pages/index.astro:3:7 - error ts(2322): ..."
             (astro-check "^\\([^ \t\n:]+\\.[[:alnum:]]+\\):\\([0-9]+\\):\\([0-9]+\\) - \\(?:error\\|\\(warning\\)\\|\\(hint\\)\\)"
                          1 2 3 (4 . 5))))
    (add-to-list 'compilation-error-regexp-alist-alist entry))

  (defvar dd/astro-compilation-error-regexp-alist '(astro-location astro-reload astro-check gnu))

  (define-compilation-mode dd/astro-compilation-mode "Astro"
    "Compilation mode for Astro dev servers, builds and package scripts."
    (add-hook 'compilation-filter-hook #'dd/astro--detect-url-h 90 t)))

(defun dd/astro--buffer-name (root kind)
  "Return the compilation buffer name for KIND in ROOT."
  (format "*astro %s: %s*" kind (abbreviate-file-name (directory-file-name root))))

(defun dd/astro--start (root kind command)
  "Run COMMAND in ROOT in the compilation buffer for KIND; return the buffer."
  (let ((default-directory root))
    (with-current-buffer
        (compilation-start command #'dd/astro-compilation-mode
                           (lambda (_) (dd/astro--buffer-name root kind)))
      (setq-local compilation-search-path
                  (cons nil (mapcar (lambda (dir) (expand-file-name dir root)) dd/astro-content-dirs)))
      (current-buffer))))

(defun dd/astro--dev-buffer (root)
  "Return ROOT's dev server buffer if its process is alive."
  (let ((buffer (get-buffer (dd/astro--buffer-name root "dev"))))
    (and buffer (process-live-p (get-buffer-process buffer)) buffer)))

;;; Commands

(defun dd/astro-dev ()
  "Start the Astro dev server, or show it if it is already running."
  (interactive)
  (let ((root (dd/astro--root)))
    (if-let* ((buffer (dd/astro--dev-buffer root)))
        (progn (display-buffer buffer) buffer)
      (dd/astro--start root "dev" (dd/astro--dev-command root)))))

(defun dd/astro-stop ()
  "Stop the Astro dev server."
  (interactive)
  (if-let* ((buffer (dd/astro--dev-buffer (dd/astro--root))))
      (interrupt-process (get-buffer-process buffer))
    (message "Astro dev server is not running")))

(defun dd/astro-restart ()
  "Restart the Astro dev server."
  (interactive)
  (let ((root (dd/astro--root))
        (compilation-always-kill t))
    (dd/astro--start root "dev" (dd/astro--dev-command root))))

(defun dd/astro-build ()
  "Build the Astro site."
  (interactive)
  (let ((root (dd/astro--root)))
    (dd/astro--start root "build" (dd/astro--script-command root "build"))))

(defun dd/astro-run-script (script)
  "Run SCRIPT from package.json, or install dependencies."
  (interactive
   (list (completing-read "Script: " (cons "install" (dd/astro--scripts (dd/astro--root))) nil t)))
  (let ((root (dd/astro--root)))
    (dd/astro--start root script
                     (if (equal script "install")
                         (concat (dd/astro-package-manager root) " install")
                       (dd/astro--script-command root script)))))

(defun dd/astro--frontmatter-slug ()
  "Return the slug: front matter value of the current buffer, as a route."
  (save-excursion
    (goto-char (point-min))
    (when (looking-at-p "---[ \t]*$")
      (let ((end (save-excursion (forward-line 1) (re-search-forward "^---[ \t]*$" nil t))))
        (when (and end (re-search-forward "^slug:[ \t]*[\"']?\\([^\"'\n]*?\\)[\"']?[ \t]*$" end t))
          (let ((slug (string-trim (match-string-no-properties 1) "/" "/")))
            (if (string-empty-p slug) "" (concat slug "/"))))))))

(defun dd/astro-route (root file)
  "Return the URL route of FILE under one of ROOT's `dd/astro-content-dirs'."
  (cl-loop for dir in dd/astro-content-dirs
           for base = (expand-file-name dir root)
           when (file-in-directory-p file base)
           return (let ((route (replace-regexp-in-string
                                "\\(?:\\`\\|/\\)index\\'" ""
                                (file-name-sans-extension (file-relative-name file base)))))
                    (if (string-empty-p route) "" (concat (downcase route) "/")))))

(defun dd/astro-preview ()
  "Open the current page (or the site root) in a browser.
Starts the dev server first when it is not running."
  (interactive)
  (let* ((root (dd/astro--root))
         (route (or (and buffer-file-name
                         (or (dd/astro--frontmatter-slug)
                             (dd/astro-route root buffer-file-name)))
                    "")))
    (with-current-buffer (or (dd/astro--dev-buffer root) (dd/astro-dev))
      (if dd/astro--url
          (browse-url (dd/astro--url-for dd/astro--url route))
        ;; Starting (possibly on another port): open once the server reports its URL.
        (setq dd/astro--pending-route route)
        (message "The page opens once the Astro dev server is ready")))))

(after! projectile
  ;; Registered last, so it wins over projectile's generic npm/pnpm/yarn types:
  ;; SPC p c builds and SPC p R starts the dev server.
  (projectile-register-project-type 'astro #'dd/astro-root-p
                                    :project-file "package.json"
                                    :compile #'dd/astro-build
                                    :run #'dd/astro-dev))

;; :ttl nil -- closing the popup must not kill the buffer (and the server).
(set-popup-rule! "^\\*astro " :size 0.3 :quit t :select nil :ttl nil)
(set-popup-rule! "^\\*vale\\*" :size 0.3 :quit t :select nil)

(map! :leader
      (:prefix "D"                ; declared in writing-mode.el
       :desc "Preview page in browser" "p" #'dd/astro-preview
       (:prefix ("a" . "astro")
        :desc "Start / show dev server" "d" #'dd/astro-dev
        :desc "Stop dev server"         "k" #'dd/astro-stop
        :desc "Restart dev server"      "r" #'dd/astro-restart
        :desc "Open preview"            "o" #'dd/astro-preview
        :desc "Build"                   "b" #'dd/astro-build
        :desc "Run package script"      "s" #'dd/astro-run-script)))
