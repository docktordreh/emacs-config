;;; config.el -*- lexical-binding: t; -*-

(load! "modules/00-preamble")
(load! "modules/10-user")
(load! "modules/20-env")

(load! "modules/ui/theme")
(load! "modules/ui/fonts")
(load! "modules/ui/line-numbers")
(load! "modules/ui/dashboard")

(load! "modules/editing/prog")
(load! "modules/editing/copilot")
(load! "modules/editing/python")

(load! "modules/projects/projectile")
(load! "modules/projects/magit-auth")
(load! "modules/projects/treemacs-ignores")

(load! "modules/org/core")
(load! "modules/org/ux")
(load! "modules/org/agenda")
(load! "modules/org/roam")
(load! "modules/org/citar")
(load! "modules/org/caldav")

(load! "modules/commands/org-return-dwim")
(load! "modules/commands/latex-helpers")
(load! "modules/commands/org-roam-tools")

(load! "modules/system/tty-exwm")
(load! "modules/system/gpg")
