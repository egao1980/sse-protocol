(in-package #:sse-protocol/tests)

(deftest encode-decode-roundtrip
  (let* ((ev (sse-protocol:make-sse-event :id "7" :event "ping" :data "hi"))
         (wire (sse-protocol:encode-sse-event ev))
         (back (sse-protocol:decode-sse-block wire)))
    (ok (equal "7" (sse-protocol:sse-event-id back)))
    (ok (equal "ping" (sse-protocol:sse-event-type back)))
    (ok (equal "hi" (sse-protocol:sse-event-data back)))))

(deftest no-backend-signals
  (let ((sse-protocol:*sse-backend* nil))
    (ok (signals (sse-protocol:open-sse "https://example.com/sse")
                 'sse-protocol:sse-error))))
