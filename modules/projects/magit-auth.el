;;; modules/projects/magit-auth.el -*- lexical-binding: t; -*-
;; Ensure Magit can retrieve credentials via auth-source.

(setq auth-sources '("~/.config/auth/authinfo.gpg")
      auth-source-cache-expiry nil
      magit-process-find-password-functions '(magit-process-password-auth-source))
