;;; modules/ui/theme.el -*- lexical-binding: t; -*-
;; Theme setup + theme-local overrides.

(setq doom-theme 'haze-chips)

(after! doom-themes
  ;; Your custom theme helpers live next to config.el (as you already do).
  (load! "comment-chips.el"))

;; Keep diff-mode readable on the light blue background.  These faces must be
;; customized separately from Magit's diff faces.
(custom-theme-set-faces! 'haze-chips
  '(diff-added
    :foreground "#456f45"
    :background "#dcebd9")
  '(diff-removed
    :foreground "#9f4051"
    :background "#f0d9de")
  '(diff-context
    :foreground "#2b3750"
    :background "#bfcdf1")
  '(diff-header
    :foreground "#4e61b2"
    :weight bold)
  '(diff-file-header
    :foreground "#233049"
    :weight bold)
  '(diff-hunk-header
    :foreground "#6f4c9e"
    :background "#d8def4"
    :weight bold)
  '(diff-refine-added
    :foreground "#315b35"
    :background "#c7dfc2"
    :weight bold)
  '(diff-refine-removed
    :foreground "#7d2d3d"
    :background "#e8c2c8"
    :weight bold))

;; Give Writeroom more room without changing the active theme.
(after! writeroom-mode
  (setq writeroom-width 0.85
        writeroom-border-width 0
        writeroom-bottom-divider-width 0))
