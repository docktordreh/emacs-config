;;; config.el -*- lexical-binding: t; -*-

(load! "modules/00-preamble")
(load! "modules/10-user")
(load! "modules/20-env")

(load! "modules/ui/theme")
(load! "modules/ui/fonts")
(load! "modules/ui/line-numbers")
(load! "modules/ui/solaire-mode")
(load! "modules/ui/golden-ratio")
(load! "modules/ui/vertico-posframe")
(load! "modules/ui/nyan-mode")
(load! "modules/ui/dashboard")

(load! "modules/editing/prog")
(load! "modules/editing/python")
(load! "modules/editing/ai")
(load! "modules/editing/plantuml")

(load! "modules/projects/projectile")
(load! "modules/projects/dired")
(load! "modules/projects/magit-auth")
(load! "modules/projects/branch-sweep")
(load! "modules/projects/az-pr-sync")
(load! "modules/projects/sbx")
(load! "modules/projects/sbx-agent-shell")
(load! "modules/projects/receiver")
;; (load! "modules/projects/treemacs-ignores")

(load! "modules/org/core")
(load! "modules/org/ux")
(load! "modules/org/agenda")
(load! "modules/org/roam")
(load-file "/home/valentin/Projects/share/second-brain.el/second-brain.el")
;; (load! "modules/org/citar")
(load! "modules/org/latex")
(load! "modules/org/mermaid")

;; Docs-as-code: Markdown/MDX + Marksman/LTeX+/Vale (see modules/docs/README.org)
(require 'rainbow-backgrounds)
(setq rainbow-backgrounds-palette
      [dd/mdx-preview-depth-1-face dd/mdx-preview-depth-2-face
       dd/mdx-preview-depth-3-face dd/mdx-preview-depth-4-face
       dd/mdx-preview-depth-5-face])
(add-hook 'html-mode-hook #'rainbow-backgrounds-enable-html)
(add-hook 'html-ts-mode-hook #'rainbow-backgrounds-enable-html)
(add-hook 'nxml-mode-hook #'rainbow-backgrounds-enable-xml)
(add-hook 'json-mode-hook #'rainbow-backgrounds-enable-json)
(add-hook 'json-ts-mode-hook #'rainbow-backgrounds-enable-json)
(add-hook 'yaml-mode-hook #'rainbow-backgrounds-enable-yaml)
(add-hook 'yaml-ts-mode-hook #'rainbow-backgrounds-enable-yaml)
(add-hook 'web-mode-hook
          (lambda ()
            (when (and buffer-file-name
                       (string-match-p "\\.html?\\'" buffer-file-name))
              (rainbow-backgrounds-enable-html))))
(global-rainbow-backgrounds-mode 1)
(map! :leader :desc "Rainbow backgrounds" "t R" #'global-rainbow-backgrounds-mode)
(load! "modules/docs/writing-mode")
(load! "modules/docs/markdown")
(load! "modules/docs/lsp")
(load! "modules/docs/vale")
(load! "modules/docs/snippets")
(load! "modules/docs/mermaid")

(load! "modules/commands/org-return-dwim")
(load! "modules/commands/latex-helpers")
(load! "modules/commands/org-roam-tools")
(load! "modules/commands/project-new")

(load! "modules/system/tty-exwm")
(load! "modules/system/gpg")
(after! org
  (require 'ox-extra)
  (ox-extras-activate '(ignore-headlines)))
