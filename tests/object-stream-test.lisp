(in-package #:sse-protocol/tests)

(deftest object-stream-roundtrip
  (let ((raw (with-output-to-string (out)
               (let ((s (sse-protocol:make-sse-output-stream out)))
                 (io-protocol:write-object s (ev :id "1" :data "hello"))
                 (io-protocol:write-object s "plain")))))
    (with-input-from-string (in raw)
      (let ((s (sse-protocol:make-sse-input-stream in)))
        (let ((a (io-protocol:read-object s))
              (b (io-protocol:read-object s))
              (c (io-protocol:read-object s)))
          (ok (sse-protocol:sse-event-p a))
          (ok (equal "hello" (sse-protocol:sse-event-data a)))
          (ok (equal "plain" (sse-protocol:sse-event-data b)))
          (ok (eq :eof c)))))))

(deftest object-stream-from-reader
  (let* ((wire (wire :id "7" :data "x"))
         (reader (sse-protocol:make-sse-reader (make-string-input-stream wire)))
         (s (sse-protocol:make-sse-input-stream reader))
         (ev (io-protocol:read-object s)))
    (ok (equal "x" (sse-protocol:sse-event-data ev)))
    (ok (equal "7" (sse-protocol:sse-reader-last-event-id reader)))
    (ok (eq :eof (io-protocol:read-object s)))))

(deftest object-stream-not-prin1
  (let ((raw (with-output-to-string (out)
               (io-protocol:write-object
                (sse-protocol:make-sse-output-stream out)
                (ev :data "hi")))))
    (ok (search "data: hi" raw))
    (ok (not (search "SSE-EVENT" raw)))))
