;;; rainbow-backgrounds.el --- Backgrounds for nested document blocks -*- lexical-binding: t; -*-

;; Package-Requires: ((emacs "30.1"))
;; Version: 0.1.0

;;; Commentary:
;; `rainbow-backgrounds-mode' draws nested ranges supplied by a buffer-local
;; provider.  Set `rainbow-backgrounds-palette' to a vector of background-only
;; faces to match your theme.  HTML, XML, JSON and YAML providers are included.

;;; Code:
(require 'cl-lib)
(require 'color)
(require 'seq)
(require 'treesit)
(require 'xmltok)

(defface rainbow-backgrounds-depth-1 '((t :inherit highlight)) "Depth one." :group 'faces)
(defface rainbow-backgrounds-depth-2 '((t :inherit rainbow-backgrounds-depth-1)) "Depth two." :group 'faces)
(defface rainbow-backgrounds-depth-3 '((t :inherit rainbow-backgrounds-depth-1)) "Depth three." :group 'faces)
(defface rainbow-backgrounds-depth-4 '((t :inherit rainbow-backgrounds-depth-1)) "Depth four." :group 'faces)
(defface rainbow-backgrounds-depth-5 '((t :inherit rainbow-backgrounds-depth-1)) "Depth five." :group 'faces)

(defvar rainbow-backgrounds-palette
  [rainbow-backgrounds-depth-1 rainbow-backgrounds-depth-2 rainbow-backgrounds-depth-3
   rainbow-backgrounds-depth-4 rainbow-backgrounds-depth-5]
  "Faces cycled by nesting depth.  Theme faces should specify only backgrounds.")

(defvar-local rainbow-backgrounds-provider nil
  "Function called with a callback to supply buffer ranges.
Call the callback with a list of (BEG END DEPTH &optional SHAPE FACE).
Positions are absolute buffer positions.  SHAPE is `inline', `full'
or nil (start at the opening column).  FACE overrides the depth palette.
Do not call the callback on parse failure, to retain the last preview.")

(defvar-local rainbow-backgrounds--timer nil)
(defvar-local rainbow-backgrounds--request nil)
(defvar-local rainbow-backgrounds--restore-delimiters nil)

(defcustom rainbow-backgrounds-syntax-weight 0.8
  "Proportion of the syntax background in the blend with the block tint."
  :type 'number
  :group 'faces)

(defun rainbow-backgrounds--hide-delimiters ()
  (when (bound-and-true-p rainbow-delimiters-mode)
    (setq rainbow-backgrounds--restore-delimiters t)
    (rainbow-delimiters-mode -1)))

(defun rainbow-backgrounds--show-delimiters ()
  (remove-hook 'rainbow-delimiters-mode-hook #'rainbow-backgrounds--hide-delimiters t)
  (when rainbow-backgrounds--restore-delimiters
    (setq rainbow-backgrounds--restore-delimiters nil)
    (rainbow-delimiters-mode 1)))

(defun rainbow-backgrounds--overlay (beg end face depth &optional indent)
  (when (< beg end)
    (let ((o (make-overlay beg end)))
      (overlay-put o 'rainbow-backgrounds t)
      (overlay-put o 'rainbow-backgrounds-palette-face face)
      (overlay-put o 'face `(:inherit ,face :extend ,(numberp indent)))
      ;; Use only secondary priority, so unrelated high-priority overlays win.
      (overlay-put o 'priority (cons nil (1+ depth)))
      (overlay-put o 'rainbow-backgrounds-indent indent)
      o)))

(defun rainbow-backgrounds--clear ()
  (remove-overlays (point-min) (point-max) 'rainbow-backgrounds t))

(defun rainbow-backgrounds--face-background (face)
  "Return a background explicitly supplied by FACE or its parents."
  (cond ((and (symbolp face) (facep face) (not (eq face 'default)))
         (let ((color (face-attribute face :background nil t)))
           (and (stringp color) color)))
        ((keywordp (car-safe face))
         (or (plist-get face :background)
             (rainbow-backgrounds--face-background (plist-get face :inherit))))
        ((consp face)
         (seq-some #'rainbow-backgrounds--face-background face))))

(defun rainbow-backgrounds--blend (syntax block)
  "Blend the SYNTAX and BLOCK colors for the selected frame."
  (when-let* ((a (color-name-to-rgb syntax))
              (b (color-name-to-rgb block))
              (weight rainbow-backgrounds-syntax-weight))
    (apply #'color-rgb-to-hex
           (append (cl-mapcar (lambda (x y) (+ (* weight x) (* (- 1 weight) y))) a b)
                   '(2)))))

(defun rainbow-backgrounds--fontify-syntax (beg end)
  "After Font Lock, blend syntax background chips within BEG and END."
  (remove-overlays beg end 'rainbow-backgrounds-syntax t)
  (let ((pos beg)
        (cache (make-hash-table :test 'equal))
        (default (face-background 'default)))
    (while (< pos end)
      (let ((next (next-char-property-change pos end))
            (syntax (or (rainbow-backgrounds--face-background (get-text-property pos 'face))
                        (rainbow-backgrounds--face-background (get-text-property pos 'font-lock-face)))))
        (when (and (stringp syntax) (not (equal syntax default)))
          (when-let* ((overlay (seq-find (lambda (o) (overlay-get o 'rainbow-backgrounds-palette-face))
                                         (overlays-at pos t)))
                      (block (rainbow-backgrounds--face-background
                              (overlay-get overlay 'rainbow-backgrounds-palette-face)))
                      (key (cons syntax block))
                      (blend (or (gethash key cache)
                                 (puthash key (rainbow-backgrounds--blend syntax block) cache))))
            (let ((chip (make-overlay pos next)))
              (overlay-put chip 'rainbow-backgrounds t)
              (overlay-put chip 'rainbow-backgrounds-syntax t)
              (overlay-put chip 'priority (cons nil (1+ (cdr (overlay-get overlay 'priority)))))
              (overlay-put chip 'face `(:background ,blend :extend nil)))))
        (setq pos next)))))

(defun rainbow-backgrounds--spacer (face align)
  (propertize " " 'face face 'display `(space :align-to ,align)))

(defun rainbow-backgrounds--blank-rows ()
  (goto-char (point-min))
  (while (and (not (eobp)) (re-search-forward "^[ \t]*$" nil t))
    (let* ((end (point))
           (layers (seq-filter (lambda (o) (overlay-get o 'rainbow-backgrounds-indent))
                               (overlays-at end t))))
      (when layers
        (let ((column (current-column)) (face 'default) spans)
          (dolist (layer (reverse layers))
            (let ((indent (overlay-get layer 'rainbow-backgrounds-indent)))
              (when (> indent column)
                (push (rainbow-backgrounds--spacer face indent) spans)
                (setq column indent))
              (setq face (plist-get (overlay-get layer 'face) :inherit))))
          (let ((overlay (make-overlay end end)))
            (overlay-put overlay 'rainbow-backgrounds t)
            (overlay-put overlay 'before-string
                         (apply #'concat (nreverse
                                          (cons (rainbow-backgrounds--spacer face 'right)
                                                spans)))))))
      (forward-line 1))))

(defun rainbow-backgrounds--block (beg end face depth full)
  (goto-char beg)
  (let ((indent (if full 0 (current-column)))
        (end-of-block (save-excursion (goto-char (1- end)) (line-beginning-position 2))))
    (beginning-of-line)
    (if (zerop indent)
        (rainbow-backgrounds--overlay (point) end-of-block face depth 0)
      (while (< (point) end-of-block)
        (let* ((blank (looking-at-p "[ \t]*$"))
               (short (< (move-to-column indent) indent))
               (overlay (rainbow-backgrounds--overlay
                         (point) (line-beginning-position 2) face depth indent)))
          (when (and short overlay (not blank))
            (overlay-put overlay 'before-string (rainbow-backgrounds--spacer 'default indent))))
        (forward-line 1)))))

(defun rainbow-backgrounds--draw (ranges)
  (save-excursion
    (rainbow-backgrounds--clear)
    (pcase-dolist (`(,beg ,end ,depth . ,options) ranges)
      (when (< beg end)
        (let ((shape (car options))
              (face (or (cadr options)
                        (aref rainbow-backgrounds-palette
                              (mod depth (length rainbow-backgrounds-palette))))))
          (if (eq shape 'inline)
              (rainbow-backgrounds--overlay beg end face depth)
            (rainbow-backgrounds--block beg end face depth (eq shape 'full))))))
    (rainbow-backgrounds--blank-rows)
    (if ranges
        (progn
          (add-hook 'rainbow-delimiters-mode-hook #'rainbow-backgrounds--hide-delimiters nil t)
          (rainbow-backgrounds--hide-delimiters))
      (rainbow-backgrounds--show-delimiters))
    (when font-lock-mode (font-lock-flush))))

(defun rainbow-backgrounds--refresh (buffer)
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq rainbow-backgrounds--timer nil)
      (when (and rainbow-backgrounds-mode rainbow-backgrounds-provider)
        (let ((request (list (buffer-chars-modified-tick))))
          (setq rainbow-backgrounds--request request)
          (save-excursion
            (save-restriction
              (widen)
              (funcall rainbow-backgrounds-provider
                       (lambda (ranges)
                         (when (buffer-live-p buffer)
                           (with-current-buffer buffer
                             (when (and rainbow-backgrounds-mode
                                        (eq request rainbow-backgrounds--request)
                                        (= (car request) (buffer-chars-modified-tick)))
                               (save-restriction
                                 (widen)
                                 (rainbow-backgrounds--draw ranges))))))))))))))

(defun rainbow-backgrounds--schedule (&rest _)
  (when rainbow-backgrounds--timer (cancel-timer rainbow-backgrounds--timer))
  (setq rainbow-backgrounds--timer
        (run-with-idle-timer 0.25 nil #'rainbow-backgrounds--refresh (current-buffer))))

(defun rainbow-backgrounds--stop ()
  (when rainbow-backgrounds--timer (cancel-timer rainbow-backgrounds--timer))
  (setq rainbow-backgrounds--timer nil rainbow-backgrounds--request nil)
  (save-restriction
    (widen)
    (rainbow-backgrounds--clear))
  (rainbow-backgrounds--show-delimiters))

;;;###autoload
(define-minor-mode rainbow-backgrounds-mode
  "Tint nested document blocks without changing buffer text."
  :lighter nil
  (if rainbow-backgrounds-mode
      (progn
        (add-hook 'jit-lock-functions #'rainbow-backgrounds--fontify-syntax 90 t)
        (add-hook 'after-change-functions #'rainbow-backgrounds--schedule nil t)
        (add-hook 'kill-buffer-hook #'rainbow-backgrounds--stop nil t)
        (add-hook 'change-major-mode-hook #'rainbow-backgrounds--stop nil t)
        (rainbow-backgrounds--refresh (current-buffer)))
    (remove-hook 'jit-lock-functions #'rainbow-backgrounds--fontify-syntax t)
    (remove-hook 'after-change-functions #'rainbow-backgrounds--schedule t)
    (remove-hook 'kill-buffer-hook #'rainbow-backgrounds--stop t)
    (remove-hook 'change-major-mode-hook #'rainbow-backgrounds--stop t)
    (rainbow-backgrounds--stop)))

(defun rainbow-backgrounds--turn-on ()
  (when (and rainbow-backgrounds-provider (not rainbow-backgrounds-mode))
    (rainbow-backgrounds-mode 1)))

;;;###autoload
(define-globalized-minor-mode global-rainbow-backgrounds-mode
  rainbow-backgrounds-mode rainbow-backgrounds--turn-on
  :group 'faces)

(defun rainbow-backgrounds-element (beg end depth)
  "Describe an element, keeping inline elements inside their own text span."
  (save-excursion
    (goto-char beg)
    (list beg end depth
          (and (= (line-end-position) (save-excursion (goto-char end) (line-end-position)))
               (or (/= beg (progn (back-to-indentation) (point)))
                   (save-excursion (goto-char end) (looking-at-p "[ \t]*[^ \t\n]")))
               'inline))))

(defun rainbow-backgrounds--treesit (language kinds describe emit)
  "Report ranges for KINDS of LANGUAGE nodes via DESCRIBE and EMIT."
  (when (treesit-language-available-p language)
    (let (ranges)
      (cl-labels ((visit (node depth)
                    (let ((matched (member (treesit-node-type node) kinds)))
                      (when matched
                        (push (funcall describe node depth) ranges))
                      (dolist (child (treesit-node-children node t))
                        (visit child (if matched (1+ depth) depth))))))
        (visit (treesit-parser-root-node (treesit-parser-create language)) 0))
      (funcall emit (nreverse ranges)))))

(defun rainbow-backgrounds-html (emit)
  "Supply HTML element ranges to EMIT using the HTML Tree-sitter grammar."
  (rainbow-backgrounds--treesit
   'html '("element" "script_element" "style_element")
   (lambda (node depth)
     (rainbow-backgrounds-element (treesit-node-start node) (treesit-node-end node) depth))
   emit))

(defun rainbow-backgrounds--collection (node depth)
  "Describe a JSON or YAML collection, keeping flow collections inline."
  (let ((beg (treesit-node-start node))
        (end (treesit-node-end node)))
    (goto-char beg)
    (if (and (not (member (treesit-node-type node) '("block_mapping" "block_sequence")))
             (<= end (line-end-position)))
        (list beg end depth 'inline)
      ;; A JSON value can start after its key; tint from the key's indent.
      (back-to-indentation)
      (list (point) end depth))))

(defun rainbow-backgrounds-json (emit)
  "Supply JSON object and array ranges to EMIT."
  (rainbow-backgrounds--treesit 'json '("object" "array")
                                #'rainbow-backgrounds--collection emit))

(defun rainbow-backgrounds-yaml (emit)
  "Supply YAML mapping and sequence ranges to EMIT."
  (rainbow-backgrounds--treesit 'yaml
                                '("block_mapping" "block_sequence" "flow_mapping" "flow_sequence")
                                #'rainbow-backgrounds--collection emit))

(defun rainbow-backgrounds-xml (emit)
  "Supply XML element ranges to EMIT using Emacs's XML tokenizer."
  (let (stack (depth 0) ranges)
    (xmltok-save
     (goto-char (point-min))
     (xmltok-forward-prolog)
     (while (and (not (eobp))
                 (let ((beg (point)))
                   (xmltok-forward)
                   (> (point) beg)))
       (pcase xmltok-type
         ('start-tag (push (cons (xmltok-start-tag-qname) xmltok-start) stack)
                     (cl-incf depth))
         ('empty-element
          (push (rainbow-backgrounds-element xmltok-start (point) depth) ranges))
         ('end-tag
          (when (equal (caar stack) (xmltok-end-tag-qname))
            (cl-decf depth)
            (push (rainbow-backgrounds-element (cdr (pop stack)) (point) depth) ranges))))))
    (funcall emit ranges)))

(defun rainbow-backgrounds-enable-html ()
  "Enable backgrounds in HTML buffers when the HTML grammar is installed."
  (when (and (not (derived-mode-p 'astro-ts-mode))
             (treesit-language-available-p 'html))
    (setq-local rainbow-backgrounds-provider #'rainbow-backgrounds-html)))

(defun rainbow-backgrounds-enable-xml ()
  "Enable backgrounds in XML buffers."
  (setq-local rainbow-backgrounds-provider #'rainbow-backgrounds-xml))

(defun rainbow-backgrounds-enable-json ()
  "Enable backgrounds when the JSON grammar is installed."
  (when (treesit-language-available-p 'json)
    (setq-local rainbow-backgrounds-provider #'rainbow-backgrounds-json)))

(defun rainbow-backgrounds-enable-yaml ()
  "Enable backgrounds when the YAML grammar is installed."
  (when (treesit-language-available-p 'yaml)
    (setq-local rainbow-backgrounds-provider #'rainbow-backgrounds-yaml)))

(provide 'rainbow-backgrounds)
;;; rainbow-backgrounds.el ends here
