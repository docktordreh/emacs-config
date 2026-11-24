;;; modules/projects/sbx-agent-shell.el -*- lexical-binding: t; -*-

(require 'agent-shell)
(require 'agent-shell-opencode)
(require 'sbx)

(declare-function agent-shell--make-acp-client "agent-shell")
(declare-function agent-shell--dwim "agent-shell")
(declare-function agent-shell-make-agent-config "agent-shell")

(defvar dd/sbx-agent-shell-opencode-acp-command '("opencode" "acp")
  "OpenCode ACP command to run inside the project sandbox.")

(defun dd/sbx-agent-shell-opencode-make-client (buffer)
  "Create an Agent Shell ACP client for BUFFER inside a project sandbox."
  (with-current-buffer buffer
    (let* ((sandbox (sbx-ensure-sandbox))
           (command (sbx-sandbox-exec-command
                     sandbox dd/sbx-agent-shell-opencode-acp-command)))
      (agent-shell--make-acp-client
       :command (car command)
       :command-params (cdr command)
       :context-buffer buffer))))

(defun dd/sbx-agent-shell-opencode-make-agent-config ()
  "Create the OpenCode-in-sbx Agent Shell configuration."
  (agent-shell-make-agent-config
   :identifier 'opencode-sbx
   :mode-line-name "OpenCode (sbx)"
   :buffer-name "OpenCode (sbx)"
   :shell-prompt "OpenCode (sbx)> "
   :shell-prompt-regexp "OpenCode (sbx)> "
   :welcome-function #'agent-shell-opencode--welcome-message
   :icon-name "opencode.png"
   :client-maker #'dd/sbx-agent-shell-opencode-make-client
   :default-model-id (lambda () agent-shell-opencode-default-model-id)
   :default-session-mode-id
   (lambda () agent-shell-opencode-default-session-mode-id)
   :default-config-options
   (lambda () agent-shell-opencode-default-config-options)
   :install-instructions
   "Set `sbx-command' globally or in the project's .sbx.el."))

(defun dd/sbx-agent-shell-start ()
  "Start an OpenCode Agent Shell session inside a project sandbox."
  (interactive)
  (agent-shell--dwim :config (dd/sbx-agent-shell-opencode-make-agent-config)
                     :new-shell t))

(defun dd/sbx-agent-shell-register ()
  "Register OpenCode-in-sbx without changing Agent Shell's preference."
  (let ((maker #'dd/sbx-agent-shell-opencode-make-agent-config))
    (unless (member maker agent-shell-agent-configs)
      (setq agent-shell-agent-configs
            (if (functionp agent-shell-agent-configs)
                (let ((original agent-shell-agent-configs))
                  (lambda ()
                    (append (funcall original) (list maker))))
              (append agent-shell-agent-configs (list maker)))))))

(dd/sbx-agent-shell-register)
