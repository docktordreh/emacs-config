;;; modules/ui/golden-ratio.el -*- lexical-binding: t; -*-

(use-package! golden-ratio
  :config
  (dolist (command '(evil-window-left evil-window-right
                     evil-window-up evil-window-down))
    (add-to-list 'golden-ratio-extra-commands command))
  (golden-ratio-mode +1))
