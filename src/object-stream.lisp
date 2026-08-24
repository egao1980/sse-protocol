(in-package #:sse-protocol)

;;; High-level SSE as io-protocol object streams.
;;; Independent of keepalives: this only maps sse-event ↔ framing.

(defclass sse-object-input-stream (io-protocol:object-input-stream)
  ((reader :initarg :reader :reader sse-input-reader)))

(defclass sse-object-output-stream (io-protocol:object-output-stream)
  ())

(defun %coerce-sse-event (object)
  (etypecase object
    (sse-event object)
    (string (make-sse-event :data object))))

(defun make-sse-input-stream (source &key last-event-id include-empty include-keepalives)
  "Wrap SOURCE (stream, sse-reader, or sse-connection) as an object-input-stream.
   READ-OBJECT → SSE-EVENT or :EOF."
  (let ((reader
          (etypecase source
            (sse-connection (sse-connection-reader source))
            (sse-reader source)
            (stream (make-sse-reader source
                                     :last-event-id last-event-id
                                     :include-empty include-empty
                                     :include-keepalives include-keepalives)))))
    (make-instance 'sse-object-input-stream
                   :underlying (sse-reader-stream reader)
                   :reader reader)))

(defun make-sse-output-stream (underlying)
  "Wrap UNDERLYING as an object-output-stream. WRITE-OBJECT takes an SSE-EVENT or string."
  (make-instance 'sse-object-output-stream :underlying underlying))

(defmethod io-protocol:read-object ((s sse-object-input-stream) &key)
  (or (read-sse-event (sse-input-reader s)) :eof))

(defmethod io-protocol:write-object ((s sse-object-output-stream) object &key)
  (write-sse-event (io-protocol:underlying-stream s) (%coerce-sse-event object) :flush t)
  object)
