(in-package :lw-shell)

(defclass shell-pane (capi:interactive-pane)
  ((process :reader shell-pane-process)
   (stream :reader shell-pane-stream))
  (:default-initargs
   :top-level-function 'entry-point))

(defun entry-point (interface shell-pane stream)
  (declare (ignore interface stream))
  (startup shell-pane))

(defmethod startup ((self shell-pane))
  (with-slots (process stream) self
    (setq process (async-process:create-process "bash" :nonblock nil)
          stream (capi:interactive-pane-stream self))
    (unwind-protect (progn
                      (initialize self)
                      (mainloop self))
      (when (async-process:process-alive-p process)
        (async-process:delete-process process)))))

(defmethod initialize ((self shell-pane))
  (editor:bind-key "Beginning of Line After Prompt" "Control-a"
                   :buffer  (capi:editor-pane-buffer self))
  (mp:process-run-function (princ-to-string self)
                           ()
                           'receive-output-loop
                           self))

(defmethod mainloop ((self shell-pane))
  (loop :with stream := (shell-pane-stream self)
        :with process := (shell-pane-process self)
        :for input := (read-line stream nil nil)
        :while input
        :do (async-process:process-send-input process (string-append input #\newline))))

(defmethod receive-output-loop ((self shell-pane))
  (loop :with stream := (shell-pane-stream self)
        :and process := (shell-pane-process self)
        :for output := (async-process:process-receive-output process)
        :while output
        :do (capi:apply-in-pane-process-if-alive self
                                                 #'write-string
                                                 (trim-output output)
                                                 stream)))

(defun trim-output (string)
  (with-output-to-string (out)
    (with-input-from-string (in string)
      (loop :for line := (read-line in nil nil)
            :while line
            :for last-index := (1- (length line))
            :do (if (char= #\return (char line last-index))
                    (write-line line out :end last-index)
                    (write-string line out))))))

(defun main ()
  (capi:display
   (make-instance 'capi:interface
                  :layout (make-instance 'capi:column-layout
                                         :description (list (make-instance 'shell-pane)))
                  :best-width 800
                  :best-height 600)))
