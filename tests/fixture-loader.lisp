(in-package #:sse-protocol/tests)

;;; Frozen WHATWG / eventsource-fixtures wires. Lisp-owned dump — do not
;;; regenerate from JS. :wire forms are expanded here.

(defun unescape-wire (string)
  "Interpret \\n \\r \\t \\0 \\\\ and \\uXXXX (4 hex digits) in STRING."
  (with-output-to-string (out)
    (loop with i = 0
          with n = (length string)
          while (< i n)
          do (let ((c (char string i)))
               (cond
                 ((or (char/= c #\\) (>= (1+ i) n))
                  (write-char c out)
                  (incf i))
                 (t
                  (let ((n1 (char string (1+ i))))
                    (case n1
                      (#\n (write-char #\newline out) (incf i 2))
                      (#\r (write-char #\return out) (incf i 2))
                      (#\t (write-char #\tab out) (incf i 2))
                      (#\0 (write-char #\nul out) (incf i 2))
                      (#\\ (write-char #\\ out) (incf i 2))
                      (#\u
                       (when (> (+ i 6) n)
                         (error "truncated \\uXXXX escape in ~S" string))
                       (write-char (code-char (parse-integer (subseq string (+ i 2) (+ i 6))
                                                             :radix 16))
                                   out)
                       (incf i 6))
                      (t
                       (write-char c out)
                       (incf i))))))))))

(defun expand-wire (form)
  (cond
    ((stringp form) form)
    ((null form) "")
    ((characterp form) (string form))
    ((and (consp form) (member (first form) '(:esc :utf-8) :test #'eq))
     (unescape-wire (second form)))
    ((and (consp form) (eq (first form) :repeat))
     (destructuring-bind (item count) (rest form)
       (apply #'concatenate 'string
              (make-list count :initial-element (expand-wire item)))))
    ((and (consp form) (eq (first form) :cat))
     (apply #'concatenate 'string (mapcar #'expand-wire (rest form))))
    (t (error "bad :wire form ~S" form))))

(defun fixture-pathname (name)
  (asdf:system-relative-pathname "sse-protocol" (format nil "tests/fixtures/~a" name)))

(defun load-fixture-file (name)
  (with-open-file (in (fixture-pathname name))
    (let ((*read-eval* nil))
      (read in))))

(defun unescape-event-spec (spec)
  (loop for (k v) on spec by #'cddr
        collect k
        collect (if (stringp v) (unescape-wire v) v)))

(defun normalize-fixture (plist)
  (let ((copy (copy-list plist)))
    (setf (getf copy :wire) (expand-wire (getf copy :wire)))
    (when (getf copy :events)
      (setf (getf copy :events)
            (mapcar #'unescape-event-spec (getf copy :events))))
    copy))

(defun load-fixtures (name)
  (mapcar #'normalize-fixture (load-fixture-file name)))

(defparameter *wpt-format-fixtures*
  (load-fixtures "wpt-format.sexp"))

(defparameter *eventsource-fixtures*
  (load-fixtures "eventsource-fixtures.sexp"))

(defun fixture-name (fx)
  (getf fx :name))

(defun fixture-rows (fixtures)
  (mapcar (lambda (fx) (list (fixture-name fx) fx)) fixtures))

(defun collect-from-string (string &key include-empty)
  (with-input-from-string (in string)
    (let ((reader (sse-protocol:make-sse-reader in :include-empty include-empty)))
      (values (sse-protocol:collect-sse-events reader :include-empty include-empty)
              (sse-protocol:sse-reader-last-event-id reader)
              (sse-protocol:sse-reader-retry reader)))))

(defun call-with-octet-input (octets fn)
  (uiop:with-temporary-file (:pathname path :prefix "sse-")
    (with-open-file (out path :direction :output
                              :element-type '(unsigned-byte 8)
                              :if-exists :supersede)
      (write-sequence octets out))
    (with-open-file (in path :direction :input
                             :element-type '(unsigned-byte 8))
      (funcall fn in))))

(defun collect-from-octets (string &key include-empty)
  (call-with-octet-input (babel:string-to-octets string :encoding :utf-8)
                         (lambda (in)
                           (let ((reader (sse-protocol:make-sse-reader
                                          in :include-empty include-empty)))
                             (values (sse-protocol:collect-sse-events
                                      reader :include-empty include-empty)
                                     (sse-protocol:sse-reader-last-event-id reader)
                                     (sse-protocol:sse-reader-retry reader))))))

(defun event-matches-spec-p (ev spec)
  (flet ((chk (key getter)
           (if (member key spec)
               (equal (getf spec key) (funcall getter ev))
               t)))
    (and (chk :data #'sse-protocol:sse-event-data)
         (chk :id #'sse-protocol:sse-event-id)
         (chk :event #'sse-protocol:sse-event-type)
         (chk :retry #'sse-protocol:sse-event-retry))))

(defun normalize-last-id (id)
  (or id ""))

(defun assert-collected (events last-id retry fx)
  (let ((expected (getf fx :events)))
    (ok (= (length expected) (length events))
        (format nil "~a event count" (fixture-name fx)))
    (loop for ev in events
          for spec in expected
          for i from 0
          do (ok (event-matches-spec-p ev spec)
                 (format nil "~a event ~a ~s"
                         (fixture-name fx) i spec))))
  (when (member :last-event-id fx)
    (ok (equal (normalize-last-id (getf fx :last-event-id))
               (normalize-last-id last-id))
        (format nil "~a last-event-id" (fixture-name fx))))
  (when (member :reader-retry fx)
    (ok (eql (getf fx :reader-retry) retry)
        (format nil "~a reader-retry" (fixture-name fx)))))

(defun assert-fixture (fx &key (octets nil))
  (let ((include-empty (getf fx :include-empty)))
    (multiple-value-bind (events last-id retry)
        (if octets
            (collect-from-octets (getf fx :wire) :include-empty include-empty)
            (collect-from-string (getf fx :wire) :include-empty include-empty))
      (assert-collected events last-id retry fx))))
