;;; config.el -*- lexical-binding: t; -*-

(load! "modules/00-preamble")
(load! "modules/10-user")
(load! "modules/20-env")

(load! "modules/ui/theme")
(load! "modules/ui/fonts")
(load! "modules/ui/line-numbers")
(load! "modules/ui/nyan-mode")
(load! "modules/ui/dashboard")

(load! "modules/editing/prog")
(load! "modules/editing/python")
(load! "modules/editing/ai")

(load! "modules/projects/projectile")
(load! "modules/projects/dired")
(load! "modules/projects/magit-auth")
(load! "modules/projects/branch-sweep")
(load! "modules/projects/az-pr-sync")
(load! "modules/projects/receiver")
(load! "modules/projects/treemacs-ignores")

(load! "modules/org/core")
(load! "modules/org/ux")
(load! "modules/org/agenda")
(load! "modules/org/roam")
(load! "modules/org/citar")
(load! "modules/org/latex")
(load! "modules/org/mermaid")

(load! "modules/commands/org-return-dwim")
(load! "modules/commands/latex-helpers")
(load! "modules/commands/org-roam-tools")
(load! "modules/commands/project-new")

(load! "modules/system/tty-exwm")
(load! "modules/system/gpg")
(after! org
  (require 'ox-extra)
  (ox-extras-activate '(ignore-headlines)))
