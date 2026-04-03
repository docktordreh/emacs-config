;;; commands/org-roam-tools.el -*- lexical-binding: t; -*-

(after! org-roam

  (defgroup dd/org-roam-tags nil
    "Batch tag editing for org-roam files."
    :group 'org-roam)

  (defcustom dd/org-roam-filetags-separator ":"
    "Separator used for #+filetags: entries."
    :type 'string
    :group 'dd/org-roam-tags)

  (defun dd/org-roam--parse-filetags-line (line)
    "Parse a #+filetags: LINE into a list of tag strings."
    ;; Accept both ':a:b:' and 'a b' style; normalize to plain tag list.
    (let* ((raw (string-trim (replace-regexp-in-string "^#\\+filetags:\\s-*" "" line t t)))
           (raw (downcase raw)))
      (cond
       ;; Colon style
       ((string-match-p ":" raw)
        (seq-filter (lambda (s) (and (stringp s) (not (string-empty-p s))))
                    (split-string raw ":" t "[ \t\n\r]+")))
       ;; Space style
       (t
        (seq-filter (lambda (s) (and (stringp s) (not (string-empty-p s))))
                    (split-string raw "[ \t]+" t))))))

  (defun dd/org-roam--format-filetags (tags)
    "Format TAGS (list of strings) into ':a:b:' form."
    (let ((tags (seq-uniq (seq-filter #'identity (mapcar (lambda (t) (downcase (string-trim t))) tags)))))
      (concat dd/org-roam-filetags-separator
              (mapconcat #'identity tags dd/org-roam-filetags-separator)
              dd/org-roam-filetags-separator)))

  (defun dd/org-roam--collect-known-tags ()
    "Collect known tags from existing #+filetags: lines in org-roam files."
    (let ((files (org-roam-list-files))
          (acc '())
          (case-fold-search t))
      (dolist (f files)
        (when (string-suffix-p ".org" f t)
          (with-temp-buffer
            (insert-file-contents f nil 0 4000) ; read header-ish region only
            (goto-char (point-min))
            (when (re-search-forward "^#\\+filetags:\\s-*\\(.*\\)$" nil t)
              (let* ((line (match-string-no-properties 0))
                     (tags (dd/org-roam--parse-filetags-line line)))
                (setq acc (nconc tags acc)))))))
      (seq-uniq (sort acc #'string<))))

  (defun dd/org-roam--current-filetags-from-range (range)
    "Return tag list from #+filetags: line given by RANGE (BOL . EOL)."
    (let* ((line (buffer-substring-no-properties (car range) (cdr range))))
      (dd/org-roam--parse-filetags-line line)))


  (defun dd/org-roam--ensure-filetags-line-range ()
    "Ensure current buffer has a #+filetags: line.
    Return (BOL . EOL) range of that line."
    (let ((case-fold-search t))
      (save-excursion
        (goto-char (point-min))
        (cond
         ;; Found existing #+filetags:
         ((re-search-forward "^#\\+filetags:.*$" nil t)
          (cons (line-beginning-position) (line-end-position)))

         ;; Insert new #+filetags: line (prefer after #+title if present)
         (t
          (goto-char (point-min))
          (if (re-search-forward "^#\\+title:.*$" nil t)
              (end-of-line)
            (goto-char (point-min)))
          ;; Insert filetags line on the next line
          (insert "\n#+filetags: \n")
          ;; Move to the inserted #+filetags: line and return its range
          (forward-line -1)
          (cons (line-beginning-position) (line-end-position)))))))

  (defun dd/org-roam--read-tags (known current title)
    "Read tags interactively. KNOWN is completion list, CURRENT is current tag list."
    (let* ((prompt (format "Tags for %s (multi, RET to finish; empty = none): " title))
           (initial (mapconcat #'identity current ", ")))
      ;; If you prefer a simple string edit, switch to read-string.
      (completing-read-multiple prompt known nil nil initial)))

  (defun dd/org-roam--file-title (file)
    "Return the #+title of FILE or the file name if no title is found"
    (let ((case-fold-search t)
          (title nil))
      (with-temp-buffer
        ;; read only beginning as title lives in header
        (insert-file-contents file nil 0 4000)
        (goto-char (point-min))
        (when (re-search-forward "^#\\+title:\\s-*\\(.*\\S-\\)\\s-*$" nil t)
          (setq title (match-string-no-properties 1))))
      (or title (file-name-nondirectory file))))

  (defun dd/org-roam-edit-filetags-all (&optional confirm)
    "Interactively edit #+filetags: for all org-roam files, one at a time.
Adds the #+filetags: field if it is missing.

With prefix arg (C-u), ask for confirmation before saving each file.

Controls during editing:
- Save tags: finish minibuffer input
- Quit early: C-g"
    (interactive "P")
    (org-roam-db-sync)
    (let* ((files (seq-filter (lambda (f) (string-suffix-p ".org" f t))
                              (org-roam-list-files)))
           (known (dd/org-roam--collect-known-tags))
           (total (length files))
           (i 0))
      (unless files
        (user-error "No org-roam files found. Check `org-roam-directory`."))
      (dolist (file files)
        (setq i (1+ i))
        (let* ((buf (find-file-noselect file))
               (title (dd/org-roam--file-title file)))
          (with-current-buffer buf
            (unless (derived-mode-p 'org-mode)
              (kill-buffer buf)
              (cl-return))
            (save-excursion
              (save-restriction
                (widen)
                (let* ((range (dd/org-roam--ensure-filetags-line-range))
                       (current-tags (dd/org-roam--current-filetags-from-range range))
                       (title (dd/org-roam--file-title file))
                       (new-tags (progn
                                   (message "Org-roam tags [%d/%d] — %s" i total title)
                                   (dd/org-roam--read-tags known current-tags title)))
                       (formatted (if (null new-tags) "" (dd/org-roam--format-filetags new-tags)))
                       (new-line (concat "#+filetags: " formatted)))
                  ;; Update known tags
                  (setq known (seq-uniq (sort (nconc known new-tags) #'string<)))
                  ;; Replace the whole #+filetags line (never touch other keywords)
                  (delete-region (car range) (cdr range))
                  (goto-char (car range))
                  (insert new-line)
                  (when (or (not confirm)
                            (y-or-n-p (format "Save tags for %s? " title)))
                    (save-buffer))))))
          
          (kill-buffer buf)))
      (org-roam-db-sync)
      (message "Done: edited tags for %d org-roam files." total))) 

  (defgroup dd/org-roam-linkify nil
    "Utilities for linkifying text to org-roam nodes."
    :group 'org-roam)

  (defcustom dd/org-roam-linkify-min-length 3
    "Minimum length of a token to consider for linkification."
    :type 'integer
    :group 'dd/org-roam-linkify)

  (defcustom dd/org-roam-linkify-token-regexp "\\b\\([[:alnum:]_+-]+\\)\\b"
    "Regexp used to find tokens to linkify. Group 1 must be the token."
    :type 'string
    :group 'dd/org-roam-linkify))

(defun dd/org-roam--current-node-id ()
  "Return the org-roam node id of the current buffer, or nil if not a roam node."
  (when (and (derived-mode-p 'org-mode)
             (buffer-file-name))
    (org-roam-node-id
     (org-roam-node-at-point))))
(defun dd/org-roam--plain-text-p (pos)
  "Return non-nil if POS is plain prose text suitable for linkification."
  (let ((props (text-properties-at pos)))
    (null props)))


(defun dd/org-roam--in-org-link-p ()
  "Return non-nil if point is inside an Org link."
  (when (derived-mode-p 'org-mode)
    (let ((ctx (org-element-context)))
      (eq (org-element-type ctx) 'link))))

(defun dd/org-roam--make-id-link (id display)
  (org-link-make-string (concat "id:" id) display))

(defun dd/org-roam--phrase-map ()
  "Return (HT . PHRASES) where HT maps downcased phrase->id, and PHRASES is a list
of phrases sorted by length (desc). Includes node titles and ROAM_ALIASES."
  (org-roam-db-sync)
  (let ((ht (make-hash-table :test 'equal))
        (phrases '()))
    ;; Titles
    (dolist (row (org-roam-db-query [:select [id title] :from nodes]))
      (pcase-let ((`(,id ,title) row))
        (when (and id (stringp title) (not (string-empty-p title)))
          (let ((k (downcase title)))
            (puthash k id ht)
            (push title phrases)))))
    ;; Aliases
    (dolist (row (org-roam-db-query [:select [node_id alias] :from aliases]))
      (pcase-let ((`(,id ,alias) row))
        (when (and id (stringp alias) (not (string-empty-p alias)))
          (let ((k (downcase alias)))
            (puthash k id ht)
            (push alias phrases)))))
    ;; Sort phrases longest-first (by length)
    (setq phrases (sort (delete-dups phrases) (lambda (a b) (> (length a) (length b)))))
    (cons ht phrases)))

(defun dd/org--in-properties-drawer-p (&optional pos)
  "Return non-nil if POS (or point) is inside a :PROPERTIES: ... :END: drawer.
Case-insensitive."
  (save-excursion
    (let ((here (or pos (point)))
          (case-fold-search t))
      (goto-char here)
      (when (re-search-backward "^\\s-*:\\(properties\\):\\s-*$" nil t)
        (let ((props-beg (point)))
          ;; If there's an :END: between :PROPERTIES: and HERE, we're not inside.
          (goto-char props-beg)
          (not (re-search-forward "^\\s-*:\\(end\\):\\s-*$" here t)))))))

(defun dd/org-roam--skip-linkify-here-p ()
  "Return non-nil if we should NOT linkify at point."
  (let ((case-fold-search t))
    (cond
     ;; never touch existing links
     ((dd/org-roam--in-org-link-p) t)

     ;; skip headings
     ((and (derived-mode-p 'org-mode) (org-at-heading-p)) t)

     ;; skip src blocks (portable enough; if org-in-src-block-p missing, remove this)
     ((and (derived-mode-p 'org-mode) (fboundp 'org-in-src-block-p) (org-in-src-block-p)) t)

     ;; skip anywhere inside a PROPERTIES drawer (any casing)
     ((and (derived-mode-p 'org-mode) (dd/org--in-properties-drawer-p)) t)

     ;; skip any #+KEY: ... line (e.g., #+title:, #+type:, etc.)
     ((save-excursion
        (beginning-of-line)
        (looking-at-p "^\\s-*#\\+[^:]+:"))
      t)

     ;; skip any property line :KEY: value (covers :roam_aliases:, :ID:, etc.)
     ((save-excursion
        (beginning-of-line)
        (looking-at-p "^\\s-*:[^:]+:\\s-+"))
      t)

     ;; skip drawer delimiter lines :PROPERTIES:, :END:, :LOGBOOK:, etc. (any casing)
     ((save-excursion
        (beginning-of-line)
        (looking-at-p "^\\s-*:[^:]+:\\s-*$"))
      t)

     (t nil))))

(defun dd/org-roam-linkify-buffer (&optional beg end confirm-each)
  "Linkify Org-roam titles/aliases, including multi-word phrases (e.g. \"Verifiable Credential\").

Skips lines starting with:
- ':' (properties/drawers)
- '#+' (file keywords)
- '*' (headings)
Skips existing Org links.
Avoids self-links in the node's own file.
With prefix arg (C-u), confirm each replacement."
  (interactive
   (list (if (use-region-p) (region-beginning) (point-min))
         (if (use-region-p) (region-end) (point-max))
         current-prefix-arg))
  (org-roam-db-sync)
  (let* ((current-id (dd/org-roam--current-node-id))
         (map+phrases (dd/org-roam--phrase-map))
         (ht (car map+phrases))
         (phrases (cdr map+phrases))
         (count 0)
         (case-fold-search t))
    (save-excursion
      (save-restriction
        (narrow-to-region beg end)
        ;; Process phrase-by-phrase, longest first
        (dolist (phrase phrases)
          (let* ((key (downcase phrase))
                 (id (gethash key ht)))
            (when (and id (not (equal id current-id)))
              (goto-char (point-min))
              ;; Match phrase with word boundaries around start/end to reduce false positives
              (let ((re (concat "\\b" (regexp-quote phrase) "\\b")))
                (while (re-search-forward re nil t)
                  (let* ((mbeg (match-beginning 0))
                         (mend (match-end 0))
                         (lb (max (point-min) (line-beginning-position)))
                         (le (min (point-max) (line-end-position)))
                         (line (buffer-substring-no-properties lb le)))
                    (save-excursion
                      (goto-char mbeg)
                      (unless (or (dd/org-roam--in-org-link-p)
                                  (string-match-p "^\\s-*\\*+\\s-+" line)
                                  (string-match-p "^\\s-*|" line)
                                  (string-match-p "^\\s-*#\\+[^:]+:" line)
                                  (string-match-p "^\\s-*:" line))
                        (let* ((matched (buffer-substring-no-properties mbeg mend))
                               (replacement (dd/org-roam--make-id-link id matched)))
                          (when (or (not confirm-each)
                                    (y-or-n-p (format "Linkify \"%s\" ? " matched)))
                            (goto-char mbeg)
                            (delete-region mbeg mend)
                            (insert replacement))
                          (setq count (1+ count)))))))))))))
    (message "org-roam linkify: %d links inserted." count)))


(defun dd/org-roam-linkify-file (file &optional confirm-each)
  "Open FILE, run `dd/org-roam-linkify-buffer`, save, and kill the buffer.
With CONFIRM-EACH (prefix arg), confirm each replacement."
  (let ((buf (find-file-noselect file)))
    (with-current-buffer buf
      ;; Only operate on Org files
      (when (derived-mode-p 'org-mode)
        (dd/org-roam-linkify-buffer (point-min) (point-max) confirm-each)
        (save-buffer)))
    (kill-buffer buf)))

(defun dd/org-roam-linkify-all (&optional confirm-each)
  "Linkify all Org-roam files.

Runs `dd/org-roam-linkify-buffer` over every file returned by `org-roam-list-files`.
Saves modified buffers. With prefix arg (C-u), confirm each replacement."
  (interactive "P")
  (org-roam-db-sync)
  (let* ((files (org-roam-list-files))
         (total (length files))
         (i 0))
    (unless files
      (user-error "No org-roam files found. Check `org-roam-directory`."))
    (dolist (f files)
      (setq i (1+ i))
      (message "org-roam linkify: [%d/%d] %s" i total (file-name-nondirectory f))
      (condition-case err
          (dd/org-roam-linkify-file f confirm-each)
        (error
         (message "org-roam linkify: ERROR in %s: %s" f (error-message-string err)))))
    (message "org-roam linkify: done (%d files processed)." total)))


(defcustom dd/org-roam-node-insert-edit-description t
  "If non-nil, prompt for editable link description during `org-roam-node-insert`."
  :type 'boolean
  :group 'org-roam)

(defun dd/org-roam--read-link-description (default)
  "Read a link description, prefilled with DEFAULT."
  (read-string "Link description: " default nil default))

(cl-defun dd/org-roam-node-insert (&optional filter-fn &key templates info)
  "Like `org-roam-node-insert`, but prompts for an editable link description.
Pre-fills with active region text (if any), otherwise the node title."
  (interactive)
  (unwind-protect
      (atomic-change-group
        (let* (region-text beg end
                           (_ (when (region-active-p)
                                (setq beg (set-marker (make-marker) (region-beginning)))
                                (setq end (set-marker (make-marker) (region-end)))
                                (setq region-text
                                      (org-link-display-format
                                       (buffer-substring-no-properties beg end)))))
                           ;; Let org-roam prefill the node prompt with selected text if present
                           (node (org-roam-node-read region-text filter-fn)))
          (when node
            (let* ((default-desc (or region-text (org-roam-node-formatted node)))
                   (description
                    (if dd/org-roam-node-insert-edit-description
                        (dd/org-roam--read-link-description default-desc)
                      default-desc)))
              (if (org-roam-node-id node)
                  (progn
                    (when region-text
                      (delete-region beg end)
                      (set-marker beg nil)
                      (set-marker end nil))
                    (let ((id (org-roam-node-id node)))
                      (insert (org-link-make-string (concat "id:" id) description))
                      (run-hook-with-args 'org-roam-post-node-insert-hook id description)))
                (org-roam-capture-
                 :node node
                 :info info
                 :templates templates
                 :props (append
                         (when (and beg end)
                           (list :region (cons beg end)))
                         (list :link-description description
                               :finalize 'insert-link))))))))
    (deactivate-mark)))

(advice-add 'org-roam-node-insert :override #'dd/org-roam-node-insert)
