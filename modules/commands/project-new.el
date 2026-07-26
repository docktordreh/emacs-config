;;; commands/project-new.el -*- lexical-binding: t; -*-

(defconst dd/projects-active-directory "~/Projects/active/"
  "Directory where `dd/project-new' creates projects.")

(defun dd/project-new--run (&rest args)
  "Run ARGS as a command or signal an error."
  (unless (zerop (apply #'call-process (car args) nil nil nil (cdr args)))
    (user-error "Command failed: %s" (string-join args " "))))

(defun dd/project-new (name)
  "Create a project named NAME under `dd/projects-active-directory'."
  (interactive "sProject name: ")
  (unless (string-match-p "\\`[^/]+\\'" name)
    (user-error "Project name must not contain a slash"))
  (let ((directory (expand-file-name name dd/projects-active-directory)))
    (when (file-exists-p directory)
      (user-error "Project already exists: %s" directory))
    (make-directory dd/projects-active-directory t)
    (if (y-or-n-p "Link to an origin? ")
        (let ((origin (read-string "Origin URL: ")))
          (if (and (string-match-p "github\\.com" origin)
                   (y-or-n-p "Create the GitHub repository with gh? "))
              (progn
                (make-directory directory)
                (let ((default-directory directory))
                  (dd/project-new--run "git" "init")
                  (dd/project-new--run "gh" "repo" "create" origin
                                        (if (y-or-n-p "Make repository private? ") "--private" "--public")
                                        "--source=." "--remote=origin")))
            (dd/project-new--run "git" "clone" origin directory)))
      (make-directory directory)
      (let ((default-directory directory))
        (dd/project-new--run "git" "init")))
    (projectile-add-known-project directory)
    (projectile-switch-project-by-name directory)))
