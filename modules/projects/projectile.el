;;; modules/projects/projectile.el -*- lexical-binding: t; -*-
;; Project discovery and indexing.

(setq projectile-project-search-path '("~/Projects/")
      projectile-globally-ignored-directories
      '(".idea" ".vscode" "node" "node_modules" ".git" ".svn" ".hg"
        "dist" "build" "out" ".cache" "__pycache__")
      projectile-globally-ignored-files '("TAGS" "*.log" "*.pyc")
      projectile-indexing-method 'alien
      projectile-enable-caching t
      projectile-sort-order 'recentf
      projectile-completion-system 'ivy
      projectile-switch-project-action #'projectile-dired
      projectile-dynamic-mode-line nil
      projectile-require-project-root t
      projectile-auto-discover t)


