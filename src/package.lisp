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
           #:close-sse-reader
           #:backend-read-sse-event
           #:backend-write-sse-event
           #:backend-open-sse
           #:backend-serve-sse
           #:open-sse
           #:serve-sse
           #:sse-connection
           #:sse-connection-url
           #:sse-connection-last-event-id
           #:close-sse))

(in-package #:sse-protocol)
