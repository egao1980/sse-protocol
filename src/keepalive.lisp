(in-package #:sse-protocol)

;;; Keepalives are independent of io-protocol object streams.
;;; Default wire: WHATWG comment (`: ping`). Optional named `event: ping`.

(defvar *sse-keepalive-interval* 15
  "Default idle seconds between keepalives. NIL or 0 disables.")

(defvar *sse-keepalive-style* :comment
  ":COMMENT → `: <payload>`  :EVENT → `event: <type>` plus payload data.")

(defun make-sse-keepalive-event (&key (style *sse-keepalive-style*)
                                      (payload *sse-keepalive-payload*)
                                      (event-type *sse-keepalive-event-type*))
  (ecase style
    (:comment (make-sse-event :comment payload))
    (:event (make-sse-event :event event-type
                            :data (or payload "")))))

(defun write-sse-keepalive (stream &key (style *sse-keepalive-style*)
                                     (payload *sse-keepalive-payload*)
                                     (event-type *sse-keepalive-event-type*)
                                     (flush t))
  (write-sse-event stream
                   (make-sse-keepalive-event :style style
                                             :payload payload
                                             :event-type event-type)
                   :flush flush))

(defclass sse-keepalive ()
  ((stream :initarg :stream :reader sse-keepalive-stream)
   (interval :initarg :interval :accessor sse-keepalive-interval)
   (style :initarg :style :accessor sse-keepalive-style)
   (payload :initarg :payload :accessor sse-keepalive-payload)
   (event-type :initarg :event-type :accessor sse-keepalive-event-type)
   (lock :initform (bt:make-lock "sse-keepalive") :reader sse-keepalive-lock)
   (thread :initform nil :accessor sse-keepalive-thread)
   (stop :initform nil :accessor sse-keepalive-stop-p)
   (last-activity :initform (get-internal-real-time)
                  :accessor sse-keepalive-last-activity)))

(defun make-sse-keepalive (stream &key (interval *sse-keepalive-interval*)
                                    (style *sse-keepalive-style*)
                                    (payload *sse-keepalive-payload*)
                                    (event-type *sse-keepalive-event-type*)
                                    (start t))
  (let ((ka (make-instance 'sse-keepalive
                           :stream stream
                           :interval interval
                           :style style
                           :payload payload
                           :event-type event-type)))
    (when (and start interval (plusp interval))
      (start-sse-keepalive ka))
    ka))

(defun note-sse-activity (keepalive)
  (setf (sse-keepalive-last-activity keepalive) (get-internal-real-time))
  keepalive)

(defun %idle-seconds (keepalive)
  (/ (float (- (get-internal-real-time)
               (sse-keepalive-last-activity keepalive)))
     internal-time-units-per-second))

(defun maybe-write-sse-keepalive (keepalive)
  "Write one keepalive if INTERVAL elapsed since last activity. Returns T if written."
  (let ((interval (sse-keepalive-interval keepalive)))
    (when (and interval (plusp interval)
               (>= (%idle-seconds keepalive) interval))
      (bt:with-lock-held ((sse-keepalive-lock keepalive))
        (when (>= (%idle-seconds keepalive) interval)
          (write-sse-keepalive (sse-keepalive-stream keepalive)
                               :style (sse-keepalive-style keepalive)
                               :payload (sse-keepalive-payload keepalive)
                               :event-type (sse-keepalive-event-type keepalive)
                               :flush t)
          (note-sse-activity keepalive)
          t)))))

(defun start-sse-keepalive (keepalive)
  (when (sse-keepalive-thread keepalive)
    (return-from start-sse-keepalive keepalive))
  (let ((interval (sse-keepalive-interval keepalive)))
    (unless (and interval (plusp interval))
      (return-from start-sse-keepalive keepalive))
    (setf (sse-keepalive-stop-p keepalive) nil)
    (setf (sse-keepalive-thread keepalive)
          (bt:make-thread
           (lambda ()
             (loop until (sse-keepalive-stop-p keepalive)
                   do (sleep (min interval 0.25))
                      (ignore-errors (maybe-write-sse-keepalive keepalive))))
           :name "sse-keepalive")))
  keepalive)

(defun stop-sse-keepalive (keepalive)
  (setf (sse-keepalive-stop-p keepalive) t)
  (let ((th (sse-keepalive-thread keepalive)))
    (when th
      (ignore-errors (bt:join-thread th))
      (setf (sse-keepalive-thread keepalive) nil)))
  keepalive)
