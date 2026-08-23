(in-package #:sse-protocol)

(defclass sse-event ()
  ((id :initarg :id :initform nil :accessor sse-event-id)
   (event :initarg :event :initform nil :accessor sse-event-type)
   (data :initarg :data :initform "" :accessor sse-event-data)
   (retry :initarg :retry :initform nil :accessor sse-event-retry)))

(defun make-sse-event (&rest args)
  (apply #'make-instance 'sse-event args))

(defclass sse-backend () ())

(defvar *sse-backend* nil)

(defun encode-sse-event (event &key)
  (with-output-to-string (out)
    (when (sse-event-id event)
      (format out "id: ~a~%" (sse-event-id event)))
    (when (sse-event-type event)
      (format out "event: ~a~%" (sse-event-type event)))
    (when (sse-event-retry event)
      (format out "retry: ~a~%" (sse-event-retry event)))
    (let ((data (or (sse-event-data event) "")))
      (if (find #\newline data)
          (dolist (line (uiop:split-string data :separator '(#\newline)))
            (format out "data: ~a~%" line))
          (format out "data: ~a~%" data)))
    (terpri out)))

(defun decode-sse-block (string &key)
  (let ((id nil) (event nil) (retry nil) (data-parts '()))
    (dolist (raw (uiop:split-string string :separator '(#\newline)))
      (let ((line (string-right-trim '(#\return) raw)))
        (cond
          ((or (zerop (length line)) (char= (char line 0) #\:)))
          ((and (>= (length line) 3) (string= line "id:" :end1 3))
           (setf id (string-left-trim '(#\space) (subseq line 3))))
          ((and (>= (length line) 6) (string= line "event:" :end1 6))
           (setf event (string-left-trim '(#\space) (subseq line 6))))
          ((and (>= (length line) 6) (string= line "retry:" :end1 6))
           (setf retry (parse-integer (string-left-trim '(#\space) (subseq line 6))
                                      :junk-allowed t)))
          ((and (>= (length line) 5) (string= line "data:" :end1 5))
           (push (string-left-trim '(#\space) (subseq line 5)) data-parts)))))
    (make-sse-event :id id :event event :retry retry
                    :data (format nil "~{~a~^~%~}" (nreverse data-parts)))))

(defgeneric backend-read-sse-event (backend stream &key))
(defgeneric backend-write-sse-event (backend stream event &key flush))
(defgeneric backend-open-sse (backend url &key last-event-id headers timeout))
(defgeneric backend-serve-sse (backend handler &key))

(defun %ensure-backend (&optional (backend *sse-backend*))
  (or backend
      (error 'sse-error :message "*sse-backend* is nil — load sse-backend-http or sse-backend-clack")))

(defun read-sse-event (stream &key (backend *sse-backend*))
  (backend-read-sse-event (%ensure-backend backend) stream))

(defun write-sse-event (stream event &key (backend *sse-backend*) flush)
  (backend-write-sse-event (%ensure-backend backend) stream event :flush flush))

(defun open-sse (url &key last-event-id headers timeout (backend *sse-backend*))
  (backend-open-sse (%ensure-backend backend) url
                    :last-event-id last-event-id :headers headers :timeout timeout))
