(in-package #:sse-protocol/tests)

(defun ev (&rest args)
  (apply #'sse-protocol:make-sse-event args))

(defun wire (&rest args)
  (sse-protocol:encode-sse-event (apply #'ev args)))

(defun decode (string)
  (sse-protocol:decode-sse-block string))

(defun event= (a b)
  (and (equal (sse-protocol:sse-event-id a) (sse-protocol:sse-event-id b))
       (equal (sse-protocol:sse-event-type a) (sse-protocol:sse-event-type b))
       (equal (sse-protocol:sse-event-data a) (sse-protocol:sse-event-data b))
       (eql (sse-protocol:sse-event-retry a) (sse-protocol:sse-event-retry b))))

(defun events= (as bs)
  (and (= (length as) (length bs))
       (every #'event= as bs)))

(defun collect-string (string &key include-empty)
  (with-input-from-string (in string)
    (sse-protocol:collect-sse-events in :include-empty include-empty)))

(defun call-with-octet-input (octets fn)
  (uiop:with-temporary-file (:pathname path :prefix "sse-")
    (with-open-file (out path :direction :output
                              :element-type '(unsigned-byte 8)
                              :if-exists :supersede)
      (write-sequence octets out))
    (with-open-file (in path :direction :input
                             :element-type '(unsigned-byte 8))
      (funcall fn in))))

(defun collect-octets (string &key include-empty)
  (call-with-octet-input (babel:string-to-octets string :encoding :utf-8)
                         (lambda (in)
                           (sse-protocol:collect-sse-events in :include-empty include-empty))))

(deftest encode-decode-roundtrip
  (let* ((src (ev :id "7" :event "ping" :data "hi" :retry 2500))
         (back (decode (sse-protocol:encode-sse-event src))))
    (ok (event= src back))))

(deftest encode-shape
  (ok (equal (wire :data "hi")
             (format nil "data: hi~%~%")))
  (ok (equal (wire :id "1" :event "x" :data "a")
             (format nil "id: 1~%event: x~%data: a~%~%")))
  (ok (equal (wire :comment "ka" :data "z")
             (format nil ":ka~%data: z~%~%")))
  (ok (equal (wire :data (format nil "a~%b"))
             (format nil "data: a~%data: b~%~%")))
  (ok (equal (wire :comment "ka")
             (format nil ":ka~%~%"))))

(deftest decode-optional-space
  (let ((spaced (decode (format nil "data: hi~%")))
        (tight (decode (format nil "data:hi~%"))))
    (ok (equal "hi" (sse-protocol:sse-event-data spaced)))
    (ok (equal "hi" (sse-protocol:sse-event-data tight)))))

(deftest decode-field-without-colon
  (ok (equal "" (sse-protocol:sse-event-data (decode (format nil "data~%"))))))

(deftest decode-unknown-fields-ignored
  (let ((ev (decode (format nil "foo: bar~%data: x~%"))))
    (ok (equal "x" (sse-protocol:sse-event-data ev)))))

(deftest decode-retry
  (ok (= 1500 (sse-protocol:sse-event-retry (decode (format nil "retry: 1500~%data: x~%")))))
  (ok (null (sse-protocol:sse-event-retry (decode (format nil "retry: 15x~%data: x~%")))))
  (ok (null (sse-protocol:sse-event-retry (decode (format nil "retry:~%data: x~%"))))))

(deftest decode-id-nul-ignored
  (let ((ev (decode (format nil "id: a~c b~%data: x~%" #\nul))))
    (ok (null (sse-protocol:sse-event-id ev)))
    (ok (equal "x" (sse-protocol:sse-event-data ev)))))

(deftest decode-comment
  (ok (equal "keep" (sse-protocol:sse-event-comment
                     (decode (format nil ": keep~%data: x~%")))))
  (ok (equal "keep" (sse-protocol:sse-event-comment
                     (decode (format nil ":keep~%data: x~%"))))))

(deftest empty-data-skipped
  (ok (null (collect-string (format nil "id: 1~%~%"))))
  (ok (null (collect-string (format nil ": ping~%~%"))))
  (let ((evs (collect-string (format nil "id: 1~%~%") :include-empty t)))
    (ok (= 1 (length evs)))
    (ok (equal "1" (sse-protocol:sse-event-id (first evs))))))

(deftest named-empty-event-kept
  (let ((evs (collect-string (format nil "event: ready~%~%"))))
    (ok (= 1 (length evs)))
    (ok (equal "ready" (sse-protocol:sse-event-type (first evs))))
    (ok (equal "" (sse-protocol:sse-event-data (first evs))))))

(deftest empty-event-type-is-default
  (let ((ev (decode (format nil "event: ~%data: data~%"))))
    (ok (null (sse-protocol:sse-event-type ev)))
    (ok (equal "data" (sse-protocol:sse-event-data ev))))
  (ok (null (collect-string (format nil "event:~%~%")))))

(deftest incomplete-eof-discarded
  (ok (null (collect-string (format nil "data: partial"))))
  (ok (null (collect-string (format nil "data: partial~%")))))

(deftest last-event-id-sticky
  (let* ((wire (format nil "id: 7~%data: a~%~%data: b~%~%"))
         (reader (sse-protocol:make-sse-reader (make-string-input-stream wire))))
    (let ((a (sse-protocol:read-sse-event reader))
          (b (sse-protocol:read-sse-event reader)))
      (ok (equal "7" (sse-protocol:sse-event-id a)))
      (ok (equal "7" (sse-protocol:sse-event-id b)))
      (ok (equal "7" (sse-protocol:sse-reader-last-event-id reader)))
      (ok (equal "b" (sse-protocol:sse-event-data b))))))

(deftest last-event-id-updates-on-skipped
  (let* ((wire (format nil "id: 9~%~%data: later~%~%"))
         (reader (sse-protocol:make-sse-reader (make-string-input-stream wire)))
         (ev (sse-protocol:read-sse-event reader)))
    (ok (equal "later" (sse-protocol:sse-event-data ev)))
    (ok (equal "9" (sse-protocol:sse-event-id ev)))
    (ok (equal "9" (sse-protocol:sse-reader-last-event-id reader)))))

(deftest retry-updates-on-skipped
  (let* ((wire (format nil "retry: 3000~%~%data: later~%~%"))
         (reader (sse-protocol:make-sse-reader (make-string-input-stream wire)))
         (ev (sse-protocol:read-sse-event reader)))
    (ok (equal "later" (sse-protocol:sse-event-data ev)))
    (ok (= 3000 (sse-protocol:sse-reader-retry reader)))))

(deftest crlf-and-cr-lines
  (let ((crlf (collect-string (format nil "data: a~c~c~c~c" #\return #\newline #\return #\newline)))
        (cr (collect-string (format nil "data: a~c~c" #\return #\return))))
    (ok (= 1 (length crlf)))
    (ok (equal "a" (sse-protocol:sse-event-data (first crlf))))
    (ok (= 1 (length cr)))
    (ok (equal "a" (sse-protocol:sse-event-data (first cr))))))

(deftest bom-stripped
  (let* ((wire (format nil "~cdata: hello~%~%" #\ufeff))
         (evs (collect-string wire)))
    (ok (= 1 (length evs)))
    (ok (equal "hello" (sse-protocol:sse-event-data (first evs))))))

(deftest binary-stream-roundtrip
  (let* ((wire (list (ev :id "1" :data "α")
                     (ev :event "ping" :data "ok")))
         (expect (list (ev :id "1" :data "α")
                       (ev :id "1" :event "ping" :data "ok")))
         (octets (babel:string-to-octets
                  (apply #'concatenate 'string (mapcar #'sse-protocol:encode-sse-event wire))
                  :encoding :utf-8))
         (back (call-with-octet-input octets #'sse-protocol:collect-sse-events)))
    (ok (events= expect back))))

(deftest write-read-character-stream
  (let ((src (ev :id "q" :data "z")))
    (ok (event= src
                (with-input-from-string (in (with-output-to-string (out)
                                              (sse-protocol:write-sse-event out src)))
                  (sse-protocol:read-sse-event in))))))

(deftest write-read-binary-stream
  (let ((src (ev :event "e" :data "utf-8 ✓")))
    (uiop:with-temporary-file (:pathname path :prefix "sse-w-")
      (with-open-file (out path :direction :output
                                :element-type '(unsigned-byte 8)
                                :if-exists :supersede)
        (sse-protocol:write-sse-event out src :flush t))
      (with-open-file (in path :direction :input
                               :element-type '(unsigned-byte 8))
        (ok (event= src (sse-protocol:read-sse-event in)))))))

(deftest collect-multiple
  (let* ((wire (concatenate 'string
                            (wire :id "1" :data "a")
                            (wire :id "2" :data "b")
                            (wire :data "c")))
         (evs (collect-string wire)))
    (ok (= 3 (length evs)))
    (ok (equal '("a" "b" "c") (mapcar #'sse-protocol:sse-event-data evs)))
    (ok (equal "2" (sse-protocol:sse-event-id (third evs))))))

(deftest map-sse-events
  (let ((n 0))
    (with-input-from-string (in (concatenate 'string
                                             (wire :data "1")
                                             (wire :data "2")))
      (sse-protocol:map-sse-events (lambda (ev)
                                     (declare (ignore ev))
                                     (incf n))
                                   in))
    (ok (= 2 n))))

(deftest reader-and-connection
  (let* ((wire (wire :id "x" :data "y"))
         (reader (sse-protocol:make-sse-reader (make-string-input-stream wire)
                                               :last-event-id "old"))
         (conn (make-instance 'sse-protocol:sse-connection
                              :url "http://example/sse"
                              :reader reader)))
    (ok (equal "http://example/sse" (sse-protocol:sse-connection-url conn)))
    (ok (equal "old" (sse-protocol:sse-connection-last-event-id conn)))
    (let ((ev (sse-protocol:read-sse-event conn)))
      (ok (equal "y" (sse-protocol:sse-event-data ev)))
      (ok (equal "x" (sse-protocol:sse-connection-last-event-id conn))))))

(deftest no-backend-signals
  (let ((sse-protocol:*sse-backend* nil))
    (ok (signals (sse-protocol:open-sse "https://example.com/sse")
                 'sse-protocol:sse-error))
    (ok (signals (sse-protocol:serve-sse (lambda (env) (declare (ignore env)) nil))
                 'sse-protocol:sse-error))))

(deftest binary-crlf-matches-character
  (let ((wire (format nil "id: 1~cdata: a~c~cid: 2~cdata: b~c~c"
                      #\newline #\newline #\newline
                      #\newline #\newline #\newline)))
    (ok (events= (collect-string wire) (collect-octets wire)))))
