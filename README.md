# sse-protocol

CLOS SSE (text/event-stream) protocol for cl-stack.

Part of [cl-stack](https://github.com/egao1980/cl-stack) agent-wire ([brief](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/agent-wire.md)).

Tracks: https://github.com/egao1980/cl-stack/issues/184

```lisp
(asdf:load-system "sse-protocol")

(let ((ev (sse-protocol:make-sse-event :id "1" :event "ping" :data "hi")))
  (sse-protocol:decode-sse-block (sse-protocol:encode-sse-event ev)))

(with-input-from-string (in (sse-protocol:encode-sse-event ev))
  (sse-protocol:collect-sse-events in))
```

Framing is protocol-local (`read-sse-event` / `write-sse-event`). `open-sse` / `serve-sse` need `sse-backend-http` or `sse-backend-clack`.

Dispatch follows WHATWG. `encode-sse-event` writes a bare `data:` line when an event with a type or id (or no fields at all) has empty or NIL data, so a browser `EventSource` fires it with data `""`. Comment-only and retry-only blocks (keepalives, retry hints) carry no data line. `read-sse-event` / `collect-sse-events` return only blocks that had a data field (`data:` alone gives `""`). A block like `event: x` with no data line is not returned unless you pass `:include-empty t`. `decode-sse-block` parses any block and returns a second value, `data-seen-p`.

`retry:` is parsed onto `sse-reader-retry`. Client reconnect (`open-sse :reconnect t` — sleep that delay, reopen with `Last-Event-ID`) lives in **sse-backend-http**, not here.

Keepalives (independent of object streams): comment `: ping` by default. `make-sse-keepalive` starts an idle timer; `read-sse-event` skips them unless `:include-keepalives t`. Style `:comment` | `:event`; interval via `*sse-keepalive-interval*` (default 15s) or `make-sse-keepalive :interval`.

Object streams (`io-protocol`, independent of keepalives):

```lisp
(let ((out (sse-protocol:make-sse-output-stream stream)))
  (io-protocol:write-object out (sse-protocol:make-sse-event :data "hi")))

(let ((in (sse-protocol:make-sse-input-stream stream)))
  (io-protocol:read-object in)) ; → sse-event or :eof
```

WHATWG `eventsource/format-*` and rexxars/eventsource-fixtures static parse routes are frozen under `tests/fixtures/*.sexp` (Lisp-owned; no JS refresh). MIME/charset/reconnect/EventSource API tests are out of scope.

```
sbcl --load scripts/roundtrip.lisp
```

CI: canned [`cl-repository`](https://github.com/egao1980/cl-repository) (`test-system.yml` / `setup-client` + `ci`). Deps from `ghcr.io/egao1980/cl-systems`.

## License

MIT
