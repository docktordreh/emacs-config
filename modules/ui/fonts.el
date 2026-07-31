;;; modules/ui/fonts.el -*- lexical-binding: t; -*-
;; Font family + sizing.

(setq doom-font (font-spec :family "IosevkaCustom" :size 28)
      doom-big-font (font-spec :family "IosevkaCustom" :size 38)
      doom-variable-pitch-font (font-spec :family "Overpass" :size 30)
      doom-serif-font (font-spec :family "BlexMono Nerd Font Mono" :size 26 :weight 'light)
      doom-symbol-font (font-spec :family "Symbola")
      doom-unicode-font (font-spec :family "JuliaMono"))


(after! emojify
  (add-hook 'doom-first-buffer-hook
            (lambda () (global-emojify-mode -1))
            t))
