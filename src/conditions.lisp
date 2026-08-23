(in-package #:sse-protocol)

(define-condition sse-error (error)
  ((message :initarg :message :reader sse-error-message :initform nil))
  (:report (lambda (c s)
             (format s "sse error~@[: ~a~]" (sse-error-message c)))))

(define-condition sse-decode-error (sse-error) ())
