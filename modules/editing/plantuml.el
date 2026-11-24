;;; modules/editing/plantuml.el -*- lexical-binding: t; -*-
;; PlantUML: use the jar from Void's `plantuml' package instead of Doom's
;; download path. Globbed because the filename carries the version.

(after! plantuml-mode
  (setq plantuml-jar-path (car (last (file-expand-wildcards "/usr/share/java/plantuml-*.jar")))
        plantuml-default-exec-mode 'jar
        org-plantuml-jar-path plantuml-jar-path))
