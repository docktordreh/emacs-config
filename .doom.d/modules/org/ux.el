;;; org/ux.el -*- lexical-binding: t; -*-

;; -------------------------------------------------------------------
;; Core Org configuration
;; -------------------------------------------------------------------
(use-package! org
  :config
  (setq org-directory "~/Nextcloud/Documents/org/"
        org-adapt-indentation t
        org-hide-leading-stars t
        org-pretty-entities t
        org-ellipsis "  ·"
        org-src-fontify-natively t
        org-src-tab-acts-natively t
        org-edit-src-content-indentation 0)

  (global-org-pretty-table-mode 1))

;; -------------------------------------------------------------------
;; Modern visuals
;; -------------------------------------------------------------------
(use-package! org-modern
  :hook (org-mode . org-modern-mode)
  :config
  (setq org-auto-align-tags t
        org-modern-block-name '("≫" . "≫")
        org-modern-tag nil
        org-modern-checkbox
        '((?  . "")   ;; unchecked
          (?X . "")   ;; checked
          (?- . ""))) ;; in-progress

  (global-org-modern-mode 1))

(use-package! org-appear
  :after org-modern
  :hook (org-mode . org-appear-mode)
  :config
  (setq org-hide-emphasis-markers t
        org-appear-autoemphasis t
        org-appear-autolinks t
        org-appear-autosubmarkers t))

(use-package! org-pretty-table
  :after org-modern)

;; -------------------------------------------------------------------
;; Tag icons via prettify-symbols after ligatures
;; -------------------------------------------------------------------
(defun dd/nerd-fa-glyph (name &optional height)
  "NAME is the nerd-icons-faicon name, e.g. \"graduation-cap\".
HEIGHT is optional (float), applied via face."
  (let* ((s (substring-no-properties (nerd-icons-faicon name))) ; strip props
         (s (if height
                (propertize s 'face `(:height ,height))
              s)))
    (concat s " "))) ; spacing between adjacent tags

(let ((thesis (dd/nerd-fa-glyph "nf-fa-graduation_cap" 2))
      (work   (dd/nerd-fa-glyph "nf-fa-briefcase"      2))
      (uni    (dd/nerd-fa-glyph "nf-fa-university"     2))
      (life   (dd/nerd-fa-glyph "nf-fa-heart"          2))
      (inbox  (dd/nerd-fa-glyph "nf-fa-inbox"          2))
      (emacs  (dd/nerd-fa-glyph "nf-fa-keyboard"       2))
      (gear   (dd/nerd-fa-glyph "nf-fa-cog"            2))
      (code   (dd/nerd-fa-glyph "nf-fa-code"           2)))

  (add-to-list '+ligatures-extra-alist
               `(org-mode
                 . ((":thesis:" . ,thesis)
                    (":work:"   . ,work)
                    (":uni:"    . ,uni)
                    (":life:"   . ,life)
                    (":inbox:"  . ,inbox)
                    (":emacs:"  . ,emacs)
                    (":code:"   . ,code)
                    (":properties:" . ,gear)))))
;; -------------------------------------------------------------------
;; Writing environment
;; -------------------------------------------------------------------
(add-hook! 'org-mode-hook
           #'variable-pitch-mode
           #'writeroom-mode)
