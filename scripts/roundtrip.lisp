;;;; Dogfood encode/decode + stream I/O. Exit 0 on success.
;;;;   sbcl --load scripts/roundtrip.lisp
;;;;   ros run --load scripts/roundtrip.lisp

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&roundtrip failed: ~a~%" c)
        (uiop:quit 1)))

(defun %here ()
  (uiop:pathname-directory-pathname
   (or *load-truename* *compile-file-truename*
       (uiop:getcwd))))

(defun %root ()
  (uiop:pathname-parent-directory-pathname (%here)))

(pushnew (%root) asdf:*central-registry* :test #'equal)
(asdf:load-system "sse-protocol")

(defun ev (&rest args)
  (apply #'sse-protocol:make-sse-event args))

(defun fail (fmt &rest args)
  (apply #'format *error-output* (concatenate 'string "~&FAIL: " fmt "~%") args)
  (uiop:quit 1))

(defun check (pred fmt &rest args)
  (unless pred (apply #'fail fmt args)))

(defun event= (a b)
  (and (equal (sse-protocol:sse-event-id a) (sse-protocol:sse-event-id b))
       (equal (sse-protocol:sse-event-type a) (sse-protocol:sse-event-type b))
       (equal (sse-protocol:sse-event-data a) (sse-protocol:sse-event-data b))
       (eql (sse-protocol:sse-event-retry a) (sse-protocol:sse-event-retry b))))

(defparameter *fixtures*
  (list (ev :id "1" :data "hello")
        (ev :id "1" :event "ping" :data "ok")
        (ev :id "7" :event "msg" :data (format nil "line1~%line2") :retry 1500)
        (ev :id "7" :data "αβγ")))

(dolist (src *fixtures*)
  (let ((back (sse-protocol:decode-sse-block (sse-protocol:encode-sse-event src))))
    (check (event= src back) "encode/decode ~s" (sse-protocol:sse-event-data src))))

(let* ((wire (apply #'concatenate 'string
                    (mapcar #'sse-protocol:encode-sse-event *fixtures*)))
       (from-string
        (with-input-from-string (in wire)
          (sse-protocol:collect-sse-events in))))
  (check (= (length *fixtures*) (length from-string))
         "string collect count ~a" (length from-string))
  (loop for a in *fixtures* for b in from-string
        do (check (event= a b) "string collect data ~s" (sse-protocol:sse-event-data a)))
  (uiop:with-temporary-file (:pathname path :prefix "sse-rt-")
    (with-open-file (out path :direction :output
                              :element-type '(unsigned-byte 8)
                              :if-exists :supersede)
      (dolist (ev *fixtures*)
        (sse-protocol:write-sse-event out ev))
      (sse-protocol:write-sse-event out (ev :comment "keepalive")))
    (with-open-file (in path :direction :input
                             :element-type '(unsigned-byte 8))
      (let ((from-file (sse-protocol:collect-sse-events in)))
        (check (= (length *fixtures*) (length from-file))
               "binary file collect count ~a" (length from-file))
        (loop for a in *fixtures* for b in from-file
              do (check (event= a b) "binary file ~s" (sse-protocol:sse-event-data a)))))))

(format t "~&; sse-protocol roundtrip ok (~a fixtures)~%" (length *fixtures*))
(uiop:quit 0)
