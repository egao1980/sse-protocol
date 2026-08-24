(defsystem "sse-protocol"
  :version "0.1.0"
  :description "CLOS SSE (text/event-stream) protocol for cl-stack"
  :author "egao1980"
  :license "MIT"
  :depends-on ("uiop" "babel" "bordeaux-threads" "io-protocol")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "conditions")
               (:file "protocol")
               (:file "keepalive")
               (:file "object-stream"))
  :in-order-to ((test-op (test-op "sse-protocol/tests"))))

(defsystem "sse-protocol/tests"
  :depends-on ("sse-protocol" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "protocol-test")
               (:file "keepalive-test")
               (:file "object-stream-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
