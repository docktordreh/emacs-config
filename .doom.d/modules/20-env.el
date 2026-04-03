;;; 20-env.el -*- lexical-binding: t; -*-


(setenv "PATH" (concat (getenv "PATH") ":/opt/kotlin-lsp/server/bin"))
(setenv "PATH" (concat (getenv "PATH") ":/home/valentin/.config/local/share/cargo/bin"))
(setenv "PATH" (concat (getenv "PATH") ":/home/valentin/.pyenv/bin"))
(add-to-list 'exec-path "/opt/texlive/2025/bin/x86_64-linux/")
