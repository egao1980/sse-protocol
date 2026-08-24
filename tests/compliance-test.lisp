(in-package #:sse-protocol/tests)

(defun run-fixture-corpus (fixtures)
  (dolist (fx fixtures)
    (testing (fixture-name fx)
      (assert-fixture fx)
      (assert-fixture fx :octets t))))

(deftest wpt-format-corpus
  (run-fixture-corpus *wpt-format-fixtures*))

(deftest eventsource-fixtures-corpus
  (run-fixture-corpus *eventsource-fixtures*))
