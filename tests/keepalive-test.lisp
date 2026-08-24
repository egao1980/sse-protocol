(in-package #:sse-protocol/tests)

(deftest keepalive-comment-shape
  (let ((ev (sse-protocol:make-sse-keepalive-event :style :comment :payload "ping")))
    (ok (sse-protocol:sse-keepalive-p ev))
    (ok (equal (format nil ":ping~%~%") (sse-protocol:encode-sse-event ev)))))

(deftest keepalive-event-shape
  (let ((ev (sse-protocol:make-sse-keepalive-event :style :event :payload "ping")))
    (ok (sse-protocol:sse-keepalive-p ev))
    (ok (equal "ping" (sse-protocol:sse-event-type ev)))))

(deftest keepalive-not-application-ping
  (ok (not (sse-protocol:sse-keepalive-p
            (ev :event "ping" :data "ok"))))
  (ok (not (sse-protocol:sse-keepalive-p
            (ev :event "ready")))))

(deftest read-skips-keepalives
  (let* ((wire (concatenate 'string
                            (sse-protocol:encode-sse-event
                             (sse-protocol:make-sse-keepalive-event))
                            (wire :data "hi")))
         (evs (collect-string wire)))
    (ok (= 1 (length evs)))
    (ok (equal "hi" (sse-protocol:sse-event-data (first evs))))))

(deftest read-include-keepalives
  (let* ((wire (concatenate 'string
                            (sse-protocol:encode-sse-event
                             (sse-protocol:make-sse-keepalive-event))
                            (wire :data "hi")))
         (evs (sse-protocol:collect-sse-events
               (make-string-input-stream wire) :include-keepalives t)))
    (ok (= 2 (length evs)))
    (ok (sse-protocol:sse-keepalive-p (first evs)))))

(deftest write-sse-keepalive
  (let ((s (with-output-to-string (out)
             (sse-protocol:write-sse-keepalive out :style :comment :payload "ka"))))
    (ok (equal (format nil ":ka~%~%") s))))

(deftest maybe-write-after-interval
  (let ((out (make-string-output-stream)))
    (let ((ka (sse-protocol:make-sse-keepalive out :interval 0.01 :start nil)))
      (setf (sse-protocol::sse-keepalive-last-activity ka)
            (- (get-internal-real-time)
               (* 2 internal-time-units-per-second)))
      (ok (sse-protocol:maybe-write-sse-keepalive ka))
      (ok (search ":ping" (get-output-stream-string out))))))

(deftest keepalive-thread-emits
  (let ((out (make-string-output-stream))
        (ka nil))
    (unwind-protect
         (progn
           (setf ka (sse-protocol:make-sse-keepalive out :interval 0.05 :start t))
           (sleep 0.18)
           (sse-protocol:stop-sse-keepalive ka)
           (ok (search ":ping" (get-output-stream-string out))))
      (when ka (sse-protocol:stop-sse-keepalive ka)))))
