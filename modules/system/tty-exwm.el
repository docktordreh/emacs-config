;;; system/tty-exwm.el -*- lexical-binding: t; -*-


(when (not (display-graphic-p))
  (load! "my-exwm-config.el"))
