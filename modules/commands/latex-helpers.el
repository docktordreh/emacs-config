;;; commands/latex-helpers.el -*- lexical-binding: t; -*-


(defun dd/insert-gls ()
  "Insert \\gls{} and prompt for term from acronyms.tex file."
  (interactive)
  (let* ((acronyms-file (concat (file-name-directory (buffer-file-name)) "acronyms.tex"))
         (terms '()))
    (when (file-exists-p acronyms-file)
      (with-temp-buffer
        (insert-file-contents acronyms-file)
        (goto-char (point-min))
        (while (re-search-forward
                "\\\\newacronym\\(\\[.*?\\]\\)?{\\(.*?\\)}{\\(.*?\\)}{\\(.*?\\)}" nil t)
          (let ((label (match-string 2))
                (full-term (match-string 3)))
            (push (cons (format "%s (%s)" full-term label) label) terms)))))
    (if terms
        (let* ((choice (completing-read "Select term: " (mapcar #'car terms)))
               (label (cdr (assoc choice terms))))
          (insert (format "\\gls{%s}" label)))
      (message "No acronyms found in acronyms.tex"))))
(defun dd/insert-cite ()
  "Insert ~\\cite{} and prompt for term from bama.bib file."
  (interactive)
  (let* ((bib-file (concat (file-name-directory (buffer-file-name)) "../bama.bib"))
         (entries '()))
    (when (file-exists-p bib-file)
      (with-temp-buffer
        (insert-file-contents bib-file)
        (goto-char (point-min))
        (while (re-search-forward
                "@\\(\\w+\\){\\(.*?\\)," nil t)
          (let ((key (match-string 2)))
            (push key entries)))))
    (if entries
        (let ((choice (completing-read "Select citation key: " entries)))
          (insert (format "~\\cite{%s}" choice)))
      (message "No entries found in bama.bib"))))

(map! :map LaTeX-mode-map
      :i "C-j" #'dd/insert-gls
      :n "C-j" #'dd/insert-gls)
