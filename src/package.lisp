(defpackage #:sse-protocol
  (:use #:cl)
  (:nicknames #:stack-sse)
  (:export #:sse-error
           #:sse-error-message
           #:sse-decode-error
           #:sse-event
           #:sse-event-id
           #:sse-event-type
           #:sse-event-data
           #:sse-event-retry
           #:make-sse-event
           #:sse-backend
           #:*sse-backend*
           #:encode-sse-event
           #:decode-sse-block
           #:backend-read-sse-event
           #:backend-write-sse-event
           #:backend-open-sse
           #:backend-serve-sse
           #:read-sse-event
           #:write-sse-event
           #:open-sse))

(in-package #:sse-protocol)
