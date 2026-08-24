;; Frozen 2026-08-24 from web-platform-tests/wpt eventsource/ (master).
;; Lisp-owned. Wires include resources/message.py suffix (newline + extra LF)
;; unless the WPT URL uses newline=none (then only the extra LF).
;; C-escapes in strings must be doubled (\\n \\r \\t \\0 \\uXXXX) so READ leaves
;; the backslash for UNESCAPE-WIRE. Skip: format-mime-*, reconnect id tests.

(
 (:name "format-bom"
  :source "eventsource/format-bom.any.js"
  :wire (:esc "\\uFEFFdata:1\\n\\n\\uFEFFdata:2\\n\\ndata:3\\n\\n\\n")
  :events ((:data "1") (:data "3")))

 (:name "format-bom-2"
  :source "eventsource/format-bom-2.any.js"
  :wire (:esc "\\uFEFF\\uFEFFdata:1\\n\\ndata:2\\n\\ndata:3\\n\\n\\n")
  :events ((:data "2") (:data "3")))

 (:name "format-comments"
  :source "eventsource/format-comments.any.js"
  :wire (:cat (:esc "data:1\\r:\\0\\n:\\r\\ndata:2\\n:")
              (:repeat "x" 2048)
              (:esc "\\rdata:3\\n:data:fail\\r:")
              (:repeat "x" 2048)
              (:esc "\\ndata:4\\n\\n"))
  :events ((:data "1\\n2\\n3\\n4")))

 (:name "format-data-before-final-empty-line"
  :source "eventsource/format-data-before-final-empty-line.any.js"
  :wire (:esc "retry:1000\\ndata:test1\\n\\nid:test\\ndata:test2\\n")
  :events ((:data "test1"))
  :last-event-id ""
  :reader-retry 1000)

 (:name "format-field-data"
  :source "eventsource/format-field-data.any.js"
  :include-empty t
  :wire (:esc "data:\\n\\ndata\\ndata\\n\\ndata:test\\n\\n\\n")
  :events ((:data "") (:data "\\n") (:data "test")))

 (:name "format-field-event"
  :source "eventsource/format-field-event.any.js"
  :wire (:esc "event:test\\ndata:x\\n\\ndata:x\\n\\n\\n")
  :events ((:event "test" :data "x") (:data "x")))

 (:name "format-field-event-empty"
  :source "eventsource/format-field-event-empty.any.js"
  :wire (:esc "event: \\ndata:data\\n\\n\\n")
  :events ((:data "data")))

 (:name "format-field-parsing"
  :source "eventsource/format-field-parsing.any.js"
  :wire (:esc "data:\\0\\ndata:  2\\rData:1\\ndata\\0:2\\ndata:1\\r\\0data:4\\nda-ta:3\\rdata_5\\ndata:3\\rdata:\\r\\n data:32\\ndata:4\\n\\n")
  :events ((:data "\\0\\n 2\\n1\\n3\\n\\n4")))

 (:name "format-field-unknown"
  :source "eventsource/format-field-unknown.any.js"
  :wire (:esc "data:test\\n data\\ndata\\nfoobar:xxx\\njustsometext\\n:thisisacommentyay\\ndata:test\\n\\n\\n")
  :events ((:data "test\\n\\ntest")))

 (:name "format-leading-space"
  :source "eventsource/format-leading-space.any.js"
  :wire (:esc "data:\\ttest\\rdata: \\ndata:test\\n\\n\\n")
  :events ((:data "\\ttest\\n\\ntest")))

 (:name "format-newlines"
  :source "eventsource/format-newlines.any.js"
  :wire (:esc "data:test\\r\\ndata\\ndata:test\\r\\n\\r\\n")
  :events ((:data "test\\n\\ntest")))

 (:name "format-null-character"
  :source "eventsource/format-null-character.any.js"
  :wire (:esc "data:\\0\\n\\n\\n\\n")
  :events ((:data "\\0")))

 (:name "format-utf-8"
  :source "eventsource/format-utf-8.any.js"
  :wire (:esc "data:ok…\\n\\n\\n")
  :events ((:data "ok…")))

 (:name "format-field-retry"
  :source "eventsource/format-field-retry.any.js"
  :wire (:esc "retry:03000\\ndata:x\\n\\n\\n")
  :events ((:data "x"))
  :reader-retry 3000)

 (:name "format-field-retry-bogus"
  :source "eventsource/format-field-retry-bogus.any.js"
  :wire (:esc "retry:3000\\nretry:1000x\\ndata:x\\n\\n\\n")
  :events ((:data "x"))
  :reader-retry 3000)

 (:name "format-field-retry-empty"
  :source "eventsource/format-field-retry-empty.any.js"
  :wire (:esc "retry\\ndata:test\\n\\n\\n")
  :events ((:data "test")))

 (:name "format-field-id-persist"
  :source "eventsource/format-field-id-3.window.js type=1"
  :wire (:esc "id: 1\\ndata: 1\\n\\ndata: 2\\n\\nid: 2\\ndata:3\\n\\ndata:4\\n\\n")
  :events ((:data "1" :id "1")
           (:data "2" :id "1")
           (:data "3" :id "2")
           (:data "4" :id "2"))
  :last-event-id "2")

 (:name "format-field-id-reset-colon"
  :source "eventsource/format-field-id-3.window.js type=2"
  :wire (:esc "id: 1\\ndata: 1\\n\\nid:\\ndata:2\\n\\ndata:3\\n\\n")
  :events ((:data "1" :id "1")
           (:data "2" :id "")
           (:data "3" :id ""))
  :last-event-id "")

 (:name "format-field-id-reset-bare"
  :source "eventsource/format-field-id-3.window.js type=3"
  :wire (:esc "id: 1\\ndata: 1\\n\\nid\\ndata:2\\n\\ndata:3\\n\\n")
  :events ((:data "1" :id "1")
           (:data "2" :id "")
           (:data "3" :id ""))
  :last-event-id "")

 (:name "format-field-id-null-00"
  :source "eventsource/format-field-id-null.window.js"
  :wire (:esc "id: \\0\\0\\nretry: 200\\ndata: hello\\n\\n")
  :events ((:data "hello"))
  :last-event-id ""
  :reader-retry 200)

 (:name "format-field-id-null-x0"
  :source "eventsource/format-field-id-null.window.js"
  :wire (:esc "id: x\\0\\nretry: 200\\ndata: hello\\n\\n")
  :events ((:data "hello"))
  :last-event-id ""
  :reader-retry 200)

 (:name "format-field-id-null-0x"
  :source "eventsource/format-field-id-null.window.js"
  :wire (:esc "id: \\0x\\nretry: 200\\ndata: hello\\n\\n")
  :events ((:data "hello"))
  :last-event-id ""
  :reader-retry 200)

 (:name "format-field-id-null-x0x"
  :source "eventsource/format-field-id-null.window.js"
  :wire (:esc "id: x\\0x\\nretry: 200\\ndata: hello\\n\\n")
  :events ((:data "hello"))
  :last-event-id ""
  :reader-retry 200)

 (:name "format-field-id-null-space0"
  :source "eventsource/format-field-id-null.window.js"
  :wire (:esc "id:  \\0\\nretry: 200\\ndata: hello\\n\\n")
  :events ((:data "hello"))
  :last-event-id ""
  :reader-retry 200)
)
