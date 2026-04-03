;;; modules/editing/copilot.el -*- lexical-binding: t; -*-
;; GitHub Copilot completion bindings + indentation integration.

                                        ; (use-package! copilot
                                        ;   :hook (prog-mode . copilot-mode)
                                        ;   :bind (:map copilot-completion-map
                                        ;               ("<tab>"   . copilot-accept-completion)
                                        ;               ("TAB"     . copilot-accept-completion)
                                        ;               ("C-<tab>" . copilot-accept-completion-by-word)
                                        ;               ("C-TAB"   . copilot-accept-completion-by-word)
                                        ;               ("C-n"     . copilot-next-completion)
                                        ;               ("C-p"     . copilot-previous-completion))
                                        ;   :init
                                        ;   (setq copilot-indentation-alist
                                        ;         '((emacs-lisp-mode . 2)
                                        ;           (lisp-interaction-mode . 2)
                                        ;           (org-mode . 2)
                                        ;           (text-mode . 2)
                                        ;           (markdown-mode . 4)
                                        ;           (prog-mode . 2)))



