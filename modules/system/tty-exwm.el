;;; system/tty-exwm.el -*- lexical-binding: t; -*-


(when (equal (getenv "EXWM") "1")
  (load! "my-exwm-config.el"))
