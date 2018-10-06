(defsystem "lw-shell"
  :depends-on ("async-process")
  :serial t
  :components ((:file "package")
               (:file "lw-shell")))
