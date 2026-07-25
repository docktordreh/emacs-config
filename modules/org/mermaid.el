;;; modules/org/mermaid.el -*- lexical-binding: t; -*-
;; Render `mermaid' source blocks with `mmdc', without Babel evaluation.

(defvar-local dd/org-mermaid-preview-overlays nil)

(defun dd/org-mermaid-preview-merge-label-spans (file)
  "Merge Mermaid label spans so Emacs preserves their internal spaces in FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (while (re-search-forward
            "</tspan><tspan\\([^>]*class=\\\"text-inner-tspan\\\"[^>]*\\)>" nil t)
      (replace-match "" nil nil))
    (write-region nil nil file nil 'silent)))

(defun dd/org-mermaid-preview-clear ()
  (dolist (overlay dd/org-mermaid-preview-overlays)
    (when-let ((file (overlay-get overlay 'dd/org-mermaid-preview-file)))
      (when (file-exists-p file)
        (delete-file file)))
    (delete-overlay overlay))
  (setq dd/org-mermaid-preview-overlays nil))

(defun dd/org-mermaid-preview-block (block)
  (let* ((mmdc (executable-find "mmdc"))
         (file (make-temp-file "mermaid-preview-" nil ".svg"))
         (errors (get-buffer-create " *mermaid-preview-errors*"))
         (status (and mmdc
                      (with-temp-buffer
                        (insert (org-element-property :value block))
                        (call-process-region
                         (point-min) (point-max) mmdc nil errors nil "-i" "-" "-o" file "-c"
                         (expand-file-name "modules/org/mermaid.json" doom-user-dir))))))
    (if (and (integerp status) (zerop status))
        (progn
          (dd/org-mermaid-preview-merge-label-spans file)
          (let ((overlay (make-overlay
                          (org-element-property :end block)
                          (org-element-property :end block))))
            (overlay-put overlay 'after-string
                         (concat "\n" (propertize " " 'display (create-image file 'svg nil)) "\n"))
            (overlay-put overlay 'dd/org-mermaid-preview-file file)
            (push overlay dd/org-mermaid-preview-overlays)))
      (delete-file file))))

(defun dd/org-mermaid-preview ()
  "Refresh inline previews for Mermaid blocks in the current Org buffer."
  (interactive)
  (save-restriction
    (widen)
    (dd/org-mermaid-preview-clear)
    (org-element-map (org-element-parse-buffer) 'src-block
      (lambda (block)
        (when (string= (org-element-property :language block) "mermaid")
          (dd/org-mermaid-preview-block block))))))

(defun dd/org-mermaid-preview-enable ()
  (add-hook 'after-save-hook #'dd/org-mermaid-preview nil t)
  (add-hook 'after-revert-hook #'dd/org-mermaid-preview nil t)
  (add-hook 'kill-buffer-hook #'dd/org-mermaid-preview-clear nil t)
  (dd/org-mermaid-preview))

(add-hook 'org-mode-hook #'dd/org-mermaid-preview-enable)

(map! :after org
      :map org-mode-map
      :localleader
      :desc "Refresh Mermaid previews" "m" #'dd/org-mermaid-preview)
