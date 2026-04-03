;;; modules/editing/python.el -*- lexical-binding: t; -*-
;; Python: extra font-lock + auto-venv activation.

(defun my/python-highlight-types ()
  (font-lock-add-keywords nil
                          '(("\\_<[A-Z][A-Za-z0-9_]*\\_>" . font-lock-type-face))))

(defun my/python-highlight-constants ()
  (font-lock-add-keywords nil
                          '(("\\_<[A-Z][A-Z0-9_]*\\_>" . font-lock-constant-face))
                          'append))

(add-hook! 'python-mode-hook #'my/python-highlight-types)
(add-hook! 'python-mode-hook #'my/python-highlight-constants)

(defun my/python--maybe-activate-local-venv ()
  "If a sibling .env directory exists next to the current file, activate it."
  (when-let* ((file (buffer-file-name))
              (dir (file-name-directory file))
              (venv (expand-file-name ".env" dir)))
    (when (file-directory-p venv)
      (pyvenv-activate venv))))

(add-hook! 'python-mode-hook #'my/python--maybe-activate-local-venv)


