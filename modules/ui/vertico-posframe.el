;;; modules/ui/vertico-posframe.el -*- lexical-binding: t; -*-

(use-package! vertico-posframe
  :after vertico
  :config
  (setq vertico-posframe-font "IosevkaCustom-18")
  (vertico-posframe-mode +1))
