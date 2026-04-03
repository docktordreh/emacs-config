;;; comment-chips.el --- Minimal global docstring chips  -*- lexical-binding: t; -*-

(defgroup comment-chips nil
  "Block-style background chips for docstrings."
  :group 'faces)

(with-eval-after-load 'doom-themes
  (defface comment-chips-outer-face
    `((t :inherit font-lock-doc-face
       :box (:line-width -1
             :color ,(doom-blend (doom-darken (face-background 'font-lock-doc-face nil t) 0.45) (face-background 'default nil t) 0.6))))
       
    "Face used on first/last line of a docstring block."
    :group 'comment-chips))

(with-eval-after-load 'doom-themes
  (defface comment-chips-middle-face
    `((t :inherit font-lock-doc-face))
    
    "Face used on middle lines of a docstring block."
    :group 'comment-chips))


;; ---- helpers ---------------------------------------------------------
(defun comment-chips--line-has-docstring-p (&optional pos)
  "Return non-nil if the line at POS contains a docstring.

We check from the first non-whitespace character on the line,
so that leading indentation before \"\" does not break detection."
  (save-excursion
    (goto-char (or pos (point)))
    (beginning-of-line)
    (skip-chars-forward " \t" (line-end-position))
    (comment-chips--in-docstring-p (point))))

(defun comment-chips--line-role (pos)
  "Return the chip role for the line at POS.

Possible return values:
  :first   – first line of a docstring block
  :middle  – middle line
  :last    – last line
  :single  – only line in the block
Nil means: not in a docstring."
  (save-excursion
    (goto-char pos)
    (let* ((here (comment-chips--line-has-docstring-p (point)))
           (prev (and here
                      (save-excursion
                        (forward-line -1)
                        (not (bobp))
                        (comment-chips--line-has-docstring-p
                         (point)))))
           (next (and here
                      (save-excursion
                        (forward-line 1)
                        (not (eobp))
                        (comment-chips--line-has-docstring-p
                         (point))))))
      (when here
        (cond
         ((and (not prev) (not next)) :single)
         ((not prev)                  :first)
         ((not next)                  :last)
         (t                           :middle))))))

(defun comment-chips--in-docstring-p (&optional pos)
  "Return non-nil if POS is in a docstring.

We detect this purely from faces: anything whose face list contains
`font-lock-comment-face` or `font-lock-doc-face` counts.

If POS is nil, use point."
  (let* ((pos   (or pos (point)))
         (face  (or (get-text-property pos 'face)
                    (get-char-property pos 'face)))
         (faces (if (listp face) face (list face))))
    (memq 'font-lock-doc-face faces)))

(defun comment-chips--apply-face-to-line (pos face)
  "Prepend FACE on the line that starts at POS."
  (save-excursion
    (goto-char pos)
    (let ((beg (line-beginning-position))
          (end (line-end-position)))
      ;; prepend so we don't wipe existing faces
      (font-lock-prepend-text-property beg end 'face face))))

(defun comment-chips--fontify-block (lines)
  "Given a list of line-beg positions LINES, add chip faces."
  (let ((n (length lines)))
    (cond
     ((= n 1)
      (comment-chips--apply-face-to-line
       (car lines) 'comment-chips-outer-face))
     (t
      (comment-chips--apply-face-to-line
       (car lines) 'comment-chips-outer-face)   ; first
      (dolist (ln (butlast (cdr lines)))
        (comment-chips--apply-face-to-line
         ln 'comment-chips-middle-face))        ; middles
      (comment-chips--apply-face-to-line
       (car (last lines)) 'comment-chips-outer-face))))) ; last

;; ---- jit-lock driver -------------------------------------------------

(defun comment-chips--fontify-region (beg end)
  "Jit-lock function: apply docstring chip faces between BEG and END."
  (save-excursion
    (goto-char beg)
    (beginning-of-line)
    (while (< (point) end)
      (let* ((ln-beg (point))
             (ln-end (line-end-position))
             (role   (comment-chips--line-role ln-beg)))
        (when role
          (let ((face (pcase role
                        (:first  'comment-chips-outer-face)
                        (:last   'comment-chips-outer-face)
                        (:single 'comment-chips-outer-face)
                        (:middle 'comment-chips-middle-face))))
            (when face
              (font-lock-prepend-text-property ln-beg ln-end 'face face))))

        (forward-line 1)))))

;;;###autoload
(define-minor-mode comment-chips-mode
  "Add block-style background chips to docstrings."
  :lighter " 💬"
  (if comment-chips-mode
      (progn
        ;; needed so jit-lock can safely extend across lines
        (set (make-local-variable 'font-lock-multiline) t)

        ;; register our jit-lock function
        (jit-lock-register #'comment-chips--fontify-region 'contextual)

        ;; make sure it runs *after* normal font-lock
        (when (and (boundp 'jit-lock-functions)
                   (listp jit-lock-functions))
          (setq jit-lock-functions
                (append (delq #'comment-chips--fontify-region jit-lock-functions)
                        (list #'comment-chips--fontify-region))))

        (jit-lock-refontify))
    (jit-lock-unregister #'comment-chips--fontify-region)))
;; Optional: you could also walk the buffer and strip our faces here.


;;;###autoload
(define-globalized-minor-mode global-comment-chips-mode
  comment-chips-mode
  (lambda () (comment-chips-mode 1)))

(provide 'comment-chips)
