;; Frozen 2026-08-24 from rexxars/eventsource-fixtures (main src/fixtures.ts).
;; Lisp-owned. Static parse routes only — skip timed /basic /time /huge-message,
;; HTTP /headers, and reconnect /identified /empty-retry.
;; /comments emoji payload abbreviated (comments do not affect dispatched data).
;; C-escapes must be doubled (\\n \\r \\t \\0 \\uXXXX) for READ + UNESCAPE-WIRE.

(
 (:name "bom"
  :source "rexxars/eventsource-fixtures /bom"
  :wire (:esc "\\uFEFFdata: bomful 1\\n\\n\\uFEFFdata: bomful 2\\n\\ndata: bomless 3\\n\\nevent: done\\ndata: ✔\\n\\n")
  :events ((:data "bomful 1")
           (:data "bomless 3")
           (:event "done" :data "✔")))

 (:name "cr"
  :source "rexxars/eventsource-fixtures /cr"
  :wire (:esc "data: dog\\rdata: bark\\r\\rdata: cat\\rdata: meow\\r\\revent: done\\ndata: ✔\\n\\n")
  :events ((:data "dog\\nbark")
           (:data "cat\\nmeow")
           (:event "done" :data "✔")))

 (:name "lf"
  :source "rexxars/eventsource-fixtures /lf"
  :wire (:esc "data: cow\\ndata: moo\\n\\ndata: horse\\ndata: neigh\\n\\nevent: done\\ndata: ✔\\n\\n")
  :events ((:data "cow\\nmoo")
           (:data "horse\\nneigh")
           (:event "done" :data "✔")))

 (:name "crlf"
  :source "rexxars/eventsource-fixtures /crlf"
  :wire (:esc "data: sheep\\r\\ndata: bleat\\r\\n\\r\\ndata: pig\\r\\ndata: oink\\r\\n\\r\\nevent: done\\ndata: ✔\\n\\n")
  :events ((:data "sheep\\nbleat")
           (:data "pig\\noink")
           (:event "done" :data "✔")))

 (:name "multiline"
  :source "rexxars/eventsource-fixtures /multiline"
  :wire (:esc "event: stock\\ndata: YHOO\\ndata: +2\\ndata: 10\\n\\nevent: stock\\ndata: GOOG\\ndata: -8\\ndata: 1881\\n\\nevent: done\\ndata: ✔\\n\\n")
  :events ((:event "stock" :data "YHOO\\n+2\\n10")
           (:event "stock" :data "GOOG\\n-8\\n1881")
           (:event "done" :data "✔")))

 (:name "comments"
  :source "rexxars/eventsource-fixtures /comments"
  :wire (:cat (:esc ": Hello\\n\\n")
              (:repeat ":" 300)
              (:esc "\\ndata: First\\n\\n: Первый: 第二\\ndata: Second\\n\\n")
              (:repeat (:esc ": Moop \\n") 10)
              (:esc ": ثالث\\ndata: Third\\n\\n:നാലാമത്തെ\\ndata: Fourth\\n\\n: emojis :\\ndata: Fifth\\n\\nevent: done\\ndata: ✔\\n\\n"))
  :events ((:data "First")
           (:data "Second")
           (:data "Third")
           (:data "Fourth")
           (:data "Fifth")
           (:event "done" :data "✔")))

 (:name "comments-mixed"
  :source "rexxars/eventsource-fixtures /comments-mixed"
  :wire (:cat (:esc "data:1\\r\\r:\\0\\n:\\r\\ndata:2\\n\\n:")
              (:repeat "x" 2049)
              (:esc "\\rdata:3\\n\\n:data:fail\\r:")
              (:repeat "x" 2049)
              (:esc "\\ndata:4\\n\\ndata:5"))
  :events ((:data "1") (:data "2") (:data "3") (:data "4")))

 (:name "empty-events"
  :source "rexxars/eventsource-fixtures /empty-events"
  :wire (:esc "event:\\ndata: Hello 1\\n\\nevent:\\n\\nevent: done\\ndata: ✔\\n\\n")
  :events ((:data "Hello 1")
           (:event "done" :data "✔")))

 (:name "field-parsing"
  :source "rexxars/eventsource-fixtures /field-parsing"
  :wire (:esc "data:\\0\\ndata: 2\\rData:1\\ndata\\0:2\\ndata:1\\r\\0data:4\\nda-ta:3\\rdata_5\\ndata:3\\rdata\\ndata:\\r\\n data:32\\ndata:4\\n\\nevent: done\\ndata: ✔\\n\\n")
  :events ((:data "\\0\\n2\\n1\\n3\\n\\n\\n4")
           (:event "done" :data "✔")))

 (:name "data-field-parsing"
  :source "rexxars/eventsource-fixtures /data-field-parsing"
  :include-empty t
  :wire (:esc "data:\\n\\ndata\\ndata\\n\\ndata:test\\n\\nevent: done\\ndata: ✔\\n\\n")
  :events ((:data "")
           (:data "\\n")
           (:data "test")
           (:event "done" :data "✔")))

 (:name "invalid-retry"
  :source "rexxars/eventsource-fixtures /invalid-retry"
  :wire (:esc "retry:1000\\nretry:2000x\\ndata:x\\n\\n")
  :events ((:data "x"))
  :reader-retry 1000)

 (:name "unknown-fields"
  :source "rexxars/eventsource-fixtures /unknown-fields"
  :wire (:esc "data:test\\n data\\ndata\\nfoobar:xxx\\njustsometext\\n:thisisacommentyay\\ndata:test\\n\\nevent: done\\ndata: ✔\\n\\n")
  :events ((:data "test\\n\\ntest")
           (:event "done" :data "✔")))

 (:name "multibyte-empty-line"
  :source "rexxars/eventsource-fixtures /multibyte-empty-line"
  :wire (:esc "\\n\\n\\n\\nid: 1\\ndata: 我現在都看實況不玩遊戲\\n\\nevent: done\\ndata: ✔\\n\\n")
  :events ((:id "1" :data "我現在都看實況不玩遊戲")
           (:id "1" :event "done" :data "✔"))
  :last-event-id "1")
)
