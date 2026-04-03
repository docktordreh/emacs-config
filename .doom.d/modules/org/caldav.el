;;; org/caldav.el -*- lexical-binding: t; -*-


(use-package! org-caldav
  :config
  (setq org-caldav-url "https://nc.docktordreh.com/remote.php/dav/calendars/valentin/")
  (setq org-caldav-calendars
        '((:calendar-id "personal" :inbox (expand-file-name "personal.org" org-directory))))
  
  (setq org-icalendar-timezone "Europe/Amsterdam"))

