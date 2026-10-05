;;; modules/docs/mermaid.el -*- lexical-binding: t; -*-
;; Mermaid: `mermaid-mode' highlights .mmd files and ```mermaid fences (via
;; markdown's native fontification); `SPC m '' edits a fence in mermaid-mode.
;; Rendering needs mmdc (@mermaid-js/mermaid-cli) and is optional.

(use-package! mermaid-mode
  :defer t
  :config
  (setq mermaid-flags (concat "-b white -c " (expand-file-name "modules/org/mermaid.json" doom-user-dir))))

(defun dd/docs--mermaid-block-at-point ()
  "Return (BEG . END) of the body of the ```mermaid fence around point."
  (save-excursion
    (let ((pos (point)))
      (end-of-line)
      (when (re-search-backward "^[ \t]*\\(```+\\|~~~+\\)[ \t]*mermaid\\b.*$" nil t)
        (let ((fence (match-string 1))
              (beg (line-beginning-position 2)))
          (forward-line 1)
          (when (and (re-search-forward (concat "^[ \t]*" (regexp-quote fence) "[ \t]*$") nil t)
                     (<= pos (match-end 0)))
            (cons beg (match-beginning 0))))))))

(defun dd/docs-mermaid-preview ()
  "Render the ```mermaid block at point with mmdc and show it in a popup."
  (interactive)
  (let* ((mmdc (or (executable-find "mmdc")
                   (user-error "mmdc not found; install @mermaid-js/mermaid-cli")))
         (block (or (dd/docs--mermaid-block-at-point)
                    (user-error "Point is not inside a ```mermaid block")))
         (svg (make-temp-file "mermaid-preview-" nil ".svg"))
         (errors (get-buffer-create "*mermaid errors*")))
    (with-current-buffer errors (erase-buffer))
    (unwind-protect
        (if (zerop (call-process-region
                    (car block) (cdr block) mmdc nil errors nil
                    "-i" "-" "-o" svg "-b" "white"
                    "-c" (expand-file-name "modules/org/mermaid.json" doom-user-dir)))
            (let ((image (create-image (with-temp-buffer
                                         (set-buffer-multibyte nil)
                                         (insert-file-contents-literally svg)
                                         (buffer-string))
                                       'svg t)))
              (with-current-buffer (get-buffer-create "*mermaid preview*")
                (let ((inhibit-read-only t))
                  (erase-buffer)
                  (insert-image image))
                (special-mode)
                (display-buffer (current-buffer))))
          (display-buffer errors))
      (delete-file svg))))

(set-popup-rule! "^\\*mermaid \\(preview\\|errors\\)\\*" :side 'right :size 0.45 :select nil :quit t)

(map! :after markdown-mode
      :map markdown-mode-map
      :localleader
      :desc "Mermaid preview" "m" #'dd/docs-mermaid-preview)

(map! :leader
      (:prefix "D"                ; declared in writing-mode.el
       :desc "Mermaid preview" "m" #'dd/docs-mermaid-preview))
