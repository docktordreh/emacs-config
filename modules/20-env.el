;;; 20-env.el -*- lexical-binding: t; -*-


(setenv "PATH" (concat (getenv "PATH") ":/opt/kotlin-lsp/server/bin"))
(setenv "PATH" (concat (getenv "PATH") ":/home/valentin/.config/local/share/cargo/bin"))
(setenv "PATH" (concat (getenv "PATH") ":/home/valentin/.pyenv/bin"))
(add-to-list 'exec-path "/opt/texlive/2025/bin/x86_64-linux/")

(defun my-active-ssh-agent-socket ()
  "Return a running SSH agent socket, preferring the inherited one."
  (let* ((agent-directory (expand-file-name "~/.ssh/agent"))
         (candidates (delete-dups
                      (append (list (getenv "SSH_AUTH_SOCK"))
                              (when (file-directory-p agent-directory)
                                (directory-files agent-directory t "\\`s\\."))))))
    (when (executable-find "ssh-add")
      (catch 'socket
        (dolist (socket candidates)
          (when (and socket (file-exists-p socket))
            (let ((process-environment (copy-sequence process-environment)))
              (setenv "SSH_AUTH_SOCK" socket)
              (when (zerop (process-file "ssh-add" nil nil nil "-l"))
                (throw 'socket socket)))))))))

(when-let ((socket (my-active-ssh-agent-socket)))
  (setenv "SSH_AUTH_SOCK" socket))

;; Use an available agent; report an unavailable identity in the echo area.
(setenv "GIT_SSH_COMMAND" (or (getenv "GIT_SSH_COMMAND") "ssh -o BatchMode=yes"))
