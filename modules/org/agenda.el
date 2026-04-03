;;; org/agenda.el -*- lexical-binding: t; -*-
;; Agenda files, capture templates, tags, todo keywords.

;;; modules/org/agenda.el -*- lexical-binding: t; -*-
;; Beautiful, minimal org-agenda (writeroom + clean prefix + icons + super-agenda)
;;
;; Based on ideas from LibrePhoenix:
;; - Center agenda with writeroom-mode
;; - Show only 1 day (today) by default
;; - Hide duplicate entries (deadline/scheduled/timestamp)
;; - Minimal / controlled time grid
;; - Category icons + remove redundant category text via prefix format
;; - Grouping with org-super-agenda

(after! org
  ;; ---------------------------
  ;; Layout / minimalism
  ;; ---------------------------
  ;;  (setq org-agenda-span 1
  ;;        org-agenda-start-day "+0d" ; today by default

  (setq org-agenda-entry-types '(:deadline :scheduled :timestamp :sexp))

  ;; Hide duplicates when an entry has multiple “date-ish” attributes
  (setq org-agenda-skip-timestamp-if-done t
        org-agenda-skip-deadline-if-done t
        org-agenda-skip-scheduled-if-done t
        org-agenda-skip-scheduled-if-deadline-is-shown t
        org-agenda-skip-timestamp-if-deadline-is-shown t)

  ;; Make the agenda less noisy (you already had a minimal grid; keep it explicitly)
  (setq org-agenda-current-time-string ""
        org-agenda-time-grid '((daily) (600 1200 1800) "---" "-----")) ; minimal grid

  ;; Remove redundant category/scheduling fluff in the left margin (LibrePhoenix approach)
  (setq org-agenda-prefix-format
        '((agenda . "  %?-2i %t ")
          (todo   . " %i %-12:c")
          (tags   . " %i %-12:c")
          (search . " %i %-12:c")))

  ;; ---------------------------
  ;; Centering (writeroom)
  ;; ---------------------------

  (defun dd/org-agenda-open-hook ()
    "Make agenda readable: centered + calm."
    (writeroom-mode 1)
    (hl-line-mode 1))

  (add-hook! 'org-agenda-mode-hook #'dd/org-agenda-open-hook) ;

  ;; Handy navigation like in the article: later/earlier on ] / [ 
  (map! :map org-agenda-mode-map
        :n "]" #'org-agenda-later
        :n "[" #'org-agenda-earlier)

  ;; ---------------------------
  ;; Your org-directory / files (kept, just grouped)
  ;; ---------------------------
  (setq org-directory "~/Nextcloud/Documents/org/"
        org-agenda-files
        (list (expand-file-name "inbox.org" org-directory)
              (expand-file-name "agenda/thesis.org" org-directory)
              (expand-file-name "agenda/uni.org" org-directory)
              (expand-file-name "agenda/work.org" org-directory)
              (expand-file-name "agenda/life.org" org-directory)
              (expand-file-name "agenda/someday.org" org-directory)
              (expand-file-name "agenda/tickler.org" org-directory)))

  ;; ---------------------------
  ;; Category icons (you already use this)
  ;; Tip: ensure each file has a stable #+CATEGORY: ...
  ;; ---------------------------

  (defun dd/org-agenda--marker-at-line ()
    "Return the org marker for the current agenda line, or nil."
    (or (org-agenda-get-at-bol 'org-hd-marker)
        (org-agenda-get-at-bol 'org-marker)))

  (defun dd/org-agenda--category-for-marker (m)
    "Return effective Org category for marker M."
    (when (markerp m)
      (with-current-buffer (marker-buffer m)
        (save-excursion
          (goto-char m)
          (org-get-category)))))

  (defun dd/org-agenda--icon-for-category (cat)
    "Return a nerd-icons glyph (string) for category CAT."
    (pcase cat
      ("work"    (nerd-icons-faicon "nf-fa-briefcase" :height 0.9))
      ("thesis"  (nerd-icons-faicon "nf-fa-graduation_cap" :height 0.9))
      ("uni"     (nerd-icons-faicon "nf-fa-university" :height 0.9))
      ("life"    (nerd-icons-faicon "nf-fa-heart" :height 0.9))
      ("inbox"   (nerd-icons-faicon "nf-fa-inbox" :height 0.9))
      ("birthday" (nerd-icons-faicon "nf-fa-cake_candles" :height 0.9))
      (_ "")))

  (defun dd/org-agenda--line-is-item-p ()
    "Non-nil if current line looks like an agenda item line (not a header/separator)."
    (let ((m (dd/org-agenda--marker-at-line)))
      (and (markerp m)
           ;; avoid group headers like 'Today'/'Due soon' etc.
           (not (org-agenda-get-at-bol 'org-agenda-structural-header))
           (not (org-agenda-get-at-bol 'org-category))))) ; harmless extra guard

  (defun dd/org-agenda-prepend-category-icons ()
    "Prepend category icons to agenda item lines (works with org-super-agenda)."
    (when (derived-mode-p 'org-agenda-mode)
      (let ((inhibit-read-only t))
        (save-excursion
          (goto-char (point-min))
          (while (not (eobp))
            (when (dd/org-agenda--line-is-item-p)
              (let* ((m (dd/org-agenda--marker-at-line))
                     (cat (dd/org-agenda--category-for-marker m))
                     (icon (dd/org-agenda--icon-for-category cat)))
                (when (and icon (not (string-empty-p icon)))
                  (beginning-of-line)
                  ;; Don't insert twice on refresh
                  (unless (looking-at-p (regexp-quote icon))
                    (insert icon " ")))))
            (forward-line 1))))))

  ;; Run after the agenda (and org-super-agenda) has built the buffer.
  (add-hook 'org-agenda-finalize-hook #'dd/org-agenda-prepend-category-icons)


  ;; ---------------------------
  ;; Super Agenda grouping
  ;; ---------------------------
  (use-package! org-super-agenda
    :after org-agenda
    :config
    (org-super-agenda-mode 1)

    ;; Your system is tag-heavy + file-based. These groups assume your tags:
    ;; thesis/uni/work/life + admin/deep/quick/email/call.
    (setq org-super-agenda-groups
          '(
            ;; Highest signal first
            (:name " Overdue"
             :deadline past
             :order 0
             :face error)

            (:name " Due soon"
             :deadline future
             :order 1
             :face warning)

            (:name " Today"
             :time-grid t
             :date today
             :scheduled today
             :deadline today
             :order 2)

            (:name " Quick wins"
             :tag "quick"
             :order 3)

            (:name " Deep work"
             :tag "deep"
             :order 4)

            (:name " Comms"
             :tag ("email" "call")
             :order 5)

            ;; Domain buckets
            (:name " Thesis"
             :tag "thesis"
             :order 6)

            (:name " Uni"
             :tag "uni"
             :order 7)

            (:name " Work"
             :tag "work"
             :order 8)

            (:name " Life"
             :tag "life"
             :order 9)

            ;; Catch-all
            (:name "Other"
             :anything t
             :order 99))))

  ;; ---------------------------
  ;; Capture / todo / tags (your existing settings, lightly tightened)
  ;; ---------------------------
  (setq org-log-done 'time
        org-log-into-drawer t
        org-startup-indented t
        org-hide-emphasis-markers t)

  (setq org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "WAITING(w@/!)" "INACTIVE(i)" "MEETING(m)" "|"
           "DONE(d!)" "CANCELLED(c@)")))

  (setq org-tag-alist
        '((:startgroup)
          ("thesis" . ?T) ("uni" . ?U) ("work" . ?W) ("life" . ?L)
          (:endgroup)
          ("admin" . ?a) ("deep" . ?d) ("quick" . ?q) ("email" . ?e) ("call" . ?c)))

  (setq org-capture-templates
        '(("t" "todo" entry (file org-default-notes-file)
           "* TODO %?\n%u\n%a\n" :clock-in t :clock-resume t)
          ("m" "Meeting" entry (file org-default-notes-file)
           "* MEETING with %? :MEETING:\n%t" :clock-in t :clock-resume t)
          ("d" "Diary" entry (file+datetree "~/org/diary.org")
           "* %?\n%U\n" :clock-in t :clock-resume t)
          ("i" "Idea" entry (file org-default-notes-file)
           "* %? :IDEA:\n%t" :clock-in t :clock-resume t)
          ("n" "Next Task" entry (file+headline org-default-notes-file "Tasks")
           "** NEXT %?\nDEADLINE: %t")))
  )
