(in-package #:sse-protocol)

;;; WHATWG event-stream framing. HTTP attach is backends (open-sse / serve-sse).
;;; Stream read/write lives here — no backend required.

(defclass sse-event ()
  ((id :initarg :id :initform nil :accessor sse-event-id)
   (event :initarg :event :initform nil :accessor sse-event-type)
   (data :initarg :data :initform "" :accessor sse-event-data)
   (retry :initarg :retry :initform nil :accessor sse-event-retry)
   (comment :initarg :comment :initform nil :accessor sse-event-comment)))

(defun sse-event-p (x)
  (typep x 'sse-event))

(defun make-sse-event (&rest args &key &allow-other-keys)
  (apply #'make-instance 'sse-event args))

(defclass sse-backend () ())

(defvar *sse-backend* nil)

(defclass sse-reader ()
  ((stream :initarg :stream :reader sse-reader-stream)
   (last-event-id :initarg :last-event-id :initform nil
                  :accessor sse-reader-last-event-id)
   (retry :initform nil :accessor sse-reader-retry)
   (include-empty :initarg :include-empty :initform nil
                  :reader sse-reader-include-empty-p)
   (seen-bom :initform nil :accessor %sse-reader-seen-bom-p)))

(defclass sse-connection ()
  ((url :initarg :url :reader sse-connection-url)
   (reader :initarg :reader :reader sse-connection-reader)
   (close :initarg :close :initform nil :reader sse-connection-closer)))

(defun sse-connection-last-event-id (connection)
  (sse-reader-last-event-id (sse-connection-reader connection)))

(defun close-sse-reader (reader &key abort)
  (let ((s (sse-reader-stream reader)))
    (when (and s (open-stream-p s))
      (close s :abort abort)))
  reader)

(defun close-sse (connection &key abort)
  (let ((fn (sse-connection-closer connection)))
    (when fn (funcall fn :abort abort)))
  (close-sse-reader (sse-connection-reader connection) :abort abort)
  connection)

(defun make-sse-reader (stream &key last-event-id include-empty)
  (make-instance 'sse-reader
                 :stream stream
                 :last-event-id last-event-id
                 :include-empty include-empty))

(defun %field-space-value (line colon)
  "WHATWG: if the first value char is U+0020 SPACE, drop it."
  (let ((start (1+ colon)))
    (if (and (< start (length line))
             (char= (char line start) #\space))
        (subseq line (1+ start))
        (subseq line start))))

(defun %strip-bom (line)
  (if (and (stringp line)
           (plusp (length line))
           (char= (char line 0) #\ufeff))
      (subseq line 1)
      line))

(defun encode-sse-event (event &key)
  "Serialize EVENT to a WHATWG event-stream block (trailing blank line)."
  (with-output-to-string (out)
    (when (sse-event-comment event)
      (dolist (line (uiop:split-string (sse-event-comment event)
                                       :separator '(#\newline)))
        (format out ":~a~%" line)))
    (when (sse-event-id event)
      (format out "id: ~a~%" (sse-event-id event)))
    (when (sse-event-type event)
      (format out "event: ~a~%" (sse-event-type event)))
    (when (sse-event-retry event)
      (format out "retry: ~a~%" (sse-event-retry event)))
    (let ((data (or (sse-event-data event) "")))
      (when (plusp (length data))
        (if (find #\newline data)
            (dolist (line (uiop:split-string data :separator '(#\newline)))
              (format out "data: ~a~%" line))
            (format out "data: ~a~%" data))))
    (terpri out)))

(defun decode-sse-block (string &key)
  "Parse one dispatched event block (no trailing blank line required)."
  (let ((id nil) (event nil) (retry nil) (comment nil) (data-parts '()))
    (dolist (raw (uiop:split-string string :separator '(#\newline)))
      (let ((line (string-right-trim '(#\return) raw)))
        (cond
          ((zerop (length line)))
          ((char= (char line 0) #\:)
           (setf comment (let ((c (subseq line 1)))
                           (if (and (plusp (length c)) (char= (char c 0) #\space))
                               (subseq c 1)
                               c))))
          (t
           (let* ((colon (position #\: line))
                  (name (if colon (subseq line 0 colon) line))
                  (value (if colon (%field-space-value line colon) "")))
             (cond
               ((string= name "id")
                (unless (find #\nul value)
                  (setf id value)))
               ((string= name "event")
                (setf event value))
               ((string= name "retry")
                (when (and (plusp (length value))
                           (every #'digit-char-p value))
                  (setf retry (parse-integer value))))
               ((string= name "data")
                (push value data-parts))))))))
    (make-sse-event :id id :event event :retry retry :comment comment
                    :data (format nil "~{~a~^~%~}" (nreverse data-parts)))))

(defun %binary-stream-p (stream)
  (let ((et (stream-element-type stream)))
    (or (eq et 'unsigned-byte)
        (and (consp et)
             (or (eq (car et) 'unsigned-byte)
                 (and (eq (car et) 'integer)
                      (eql (second et) 0)
                      (eql (third et) 255)))))))

(defvar *%binary-unread* (make-hash-table :test 'eq))

(defun %read-binary-byte (stream)
  (let ((pending (gethash stream *%binary-unread*)))
    (cond
      (pending
       (remhash stream *%binary-unread*)
       pending)
      (t (read-byte stream nil :eof)))))

(defun %unread-binary-byte (stream byte)
  (setf (gethash stream *%binary-unread*) byte))

(defun %octets-to-utf8 (bytes)
  (babel:octets-to-string bytes :encoding :utf-8))

(defun %read-binary-line (stream)
  "Read one CR / LF / CRLF-terminated line from a binary stream → UTF-8 string or :eof."
  (let ((bytes (make-array 0 :element-type '(unsigned-byte 8)
                              :adjustable t :fill-pointer 0)))
    (loop
      (let ((b (%read-binary-byte stream)))
        (cond
          ((eq b :eof)
           (return (if (zerop (length bytes))
                       :eof
                       (%octets-to-utf8 bytes))))
          ((= b 10)
           (return (%octets-to-utf8 bytes)))
          ((= b 13)
           (let ((n (%read-binary-byte stream)))
             (unless (or (eq n :eof) (= n 10))
               (%unread-binary-byte stream n)))
           (return (%octets-to-utf8 bytes)))
          (t (vector-push-extend b bytes)))))))

(defun %read-character-line (stream)
  "Read one CR / LF / CRLF-terminated line from a character stream."
  (let ((chars (make-array 0 :element-type 'character
                              :adjustable t :fill-pointer 0)))
    (loop
      (let ((c (read-char stream nil :eof)))
        (cond
          ((eq c :eof)
           (return (if (zerop (length chars))
                       :eof
                       (coerce chars 'string))))
          ((char= c #\newline)
           (return (coerce chars 'string)))
          ((char= c #\return)
           (let ((n (peek-char nil stream nil :eof)))
             (when (eql n #\newline)
               (read-char stream)))
           (return (coerce chars 'string)))
          (t (vector-push-extend c chars)))))))

(defun read-sse-line (stream)
  "Read one event-stream line (CR/LF stripped). :eof at end."
  (if (%binary-stream-p stream)
      (%read-binary-line stream)
      (%read-character-line stream)))

(defun %dispatchable-p (event include-empty)
  (or include-empty
      (plusp (length (or (sse-event-data event) "")))
      (sse-event-type event)))

(defun %read-sse-event (stream &key include-empty last-event-id strip-bom)
  "Read one dispatched event from STREAM.
   Returns (values event last-event-id retry). EVENT is NIL at EOF.
   Incomplete blocks at EOF are discarded (WHATWG).
   LAST-EVENT-ID / RETRY update even when the block is not dispatched."
  (let ((retry nil)
        (first-line-p strip-bom))
    (loop
      (let ((lines '())
            (saw-line nil))
        (loop
          (let ((line (read-sse-line stream)))
            (when (and first-line-p (stringp line))
              (setf line (%strip-bom line)
                    first-line-p nil))
            (cond
              ((eq line :eof)
               ;; WHATWG: pending data at EOF is discarded.
               (return-from %read-sse-event
                 (values nil last-event-id retry)))
              ((zerop (length line))
               (when saw-line (return)))
              (t
               (setf saw-line t)
               (push line lines)))))
        (let ((ev (decode-sse-block (format nil "~{~a~%~}" (nreverse lines)))))
          (when (sse-event-id ev)
            (setf last-event-id (sse-event-id ev)))
          (when (sse-event-retry ev)
            (setf retry (sse-event-retry ev)))
          (unless (sse-event-id ev)
            (setf (sse-event-id ev) last-event-id))
          (when (%dispatchable-p ev include-empty)
            (return (values ev last-event-id retry))))))))

(defun read-sse-event (source &key include-empty)
  "Read the next event from a stream, SSE-READER, or SSE-CONNECTION.
   NIL at EOF. Framing is protocol-local — no backend required."
  (etypecase source
    (sse-connection
     (read-sse-event (sse-connection-reader source) :include-empty include-empty))
    (sse-reader
     (let ((strip (not (%sse-reader-seen-bom-p source))))
       (setf (%sse-reader-seen-bom-p source) t)
       (multiple-value-bind (ev last-id retry)
           (%read-sse-event (sse-reader-stream source)
                            :include-empty (or include-empty
                                               (sse-reader-include-empty-p source))
                            :last-event-id (sse-reader-last-event-id source)
                            :strip-bom strip)
         (setf (sse-reader-last-event-id source) last-id)
         (when retry
           (setf (sse-reader-retry source) retry))
         ev)))
    (stream
     (%read-sse-event source :include-empty include-empty :strip-bom t))))

(defun write-sse-event (stream event &key flush)
  "Write EVENT onto STREAM (character or UTF-8 binary). FLUSH → finish-output."
  (let ((wire (encode-sse-event event)))
    (if (%binary-stream-p stream)
        (write-sequence (babel:string-to-octets wire :encoding :utf-8) stream)
        (write-string wire stream))
    (when flush (finish-output stream))
    event))

(defun map-sse-events (function source &key include-empty)
  "Call FUNCTION with each event from SOURCE until EOF. Returns T.
   Bare streams are wrapped in an SSE-READER so last-event-id / retry persist."
  (let ((src (if (streamp source)
                 (make-sse-reader source :include-empty include-empty)
                 source)))
    (loop for ev = (read-sse-event src :include-empty include-empty)
          while ev
          do (funcall function ev))
    t))

(defun collect-sse-events (source &key include-empty)
  (let ((out '()))
    (map-sse-events (lambda (ev) (push ev out)) source :include-empty include-empty)
    (nreverse out)))

(defgeneric backend-read-sse-event (backend stream &key)
  (:method ((backend sse-backend) stream &key include-empty)
    (read-sse-event stream :include-empty include-empty)))

(defgeneric backend-write-sse-event (backend stream event &key flush)
  (:method ((backend sse-backend) stream event &key flush)
    (write-sse-event stream event :flush flush)))

(defgeneric backend-open-sse (backend url &key last-event-id headers timeout method content)
  (:documentation "Client: open URL as an SSE connection."))

(defgeneric backend-serve-sse (backend handler &key host port path)
  (:documentation "Server: serve HANDLER (env → events | writer)."))

(defun %ensure-backend (&optional (backend *sse-backend*))
  (or backend
      (error 'sse-error
             :message "*sse-backend* is nil — load sse-backend-http or sse-backend-clack")))

(defun open-sse (url &key last-event-id headers timeout method content
                       (backend *sse-backend*))
  (backend-open-sse (%ensure-backend backend) url
                    :last-event-id last-event-id
                    :headers headers
                    :timeout timeout
                    :method method
                    :content content))

(defun serve-sse (handler &key host port path (backend *sse-backend*))
  (backend-serve-sse (%ensure-backend backend) handler
                     :host host :port port :path path))
