(defpackage #:sse-protocol
  (:use #:cl)
  (:nicknames #:stack-sse)
  (:export #:sse-error
           #:sse-error-message
           #:sse-decode-error
           #:sse-event
           #:sse-event-p
           #:sse-event-id
           #:sse-event-type
           #:sse-event-data
           #:sse-event-retry
           #:sse-event-comment
           #:make-sse-event
           #:sse-backend
           #:*sse-backend*
           #:encode-sse-event
           #:decode-sse-block
           #:read-sse-line
           #:read-sse-event
           #:write-sse-event
           #:map-sse-events
           #:collect-sse-events
           #:sse-reader
           #:make-sse-reader
           #:sse-reader-last-event-id
           #:sse-reader-retry
           #:sse-reader-stream
           #:sse-reader-include-keepalives-p
           #:close-sse-reader
           #:*sse-keepalive-interval*
           #:*sse-keepalive-style*
           #:*sse-keepalive-payload*
           #:*sse-keepalive-event-type*
           #:sse-keepalive-p
           #:make-sse-keepalive-event
           #:write-sse-keepalive
           #:sse-keepalive
           #:make-sse-keepalive
           #:start-sse-keepalive
           #:stop-sse-keepalive
           #:note-sse-activity
           #:maybe-write-sse-keepalive
           #:backend-read-sse-event
           #:backend-write-sse-event
           #:backend-open-sse
           #:backend-serve-sse
           #:open-sse
           #:serve-sse
           #:sse-connection
           #:sse-connection-url
           #:sse-connection-last-event-id
           #:close-sse
           #:sse-object-input-stream
           #:sse-object-output-stream
           #:make-sse-input-stream
           #:make-sse-output-stream))

(in-package #:sse-protocol)
