;;; modules/ui/theme.el -*- lexical-binding: t; -*-
;; Theme setup + theme-local overrides.

(setq doom-theme 'doom-haze-chips)

(after! doom-themes
  ;; Your custom theme helpers live next to config.el (as you already do).
  (load! "comment-chips.el"))


