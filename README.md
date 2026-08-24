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

CI: `setup-client` + `setup-roswell` + `scripts/ci-install.lisp` / `ci-test.lisp` (OCI, QL only for missing test pins like `dissect`).

## License

MIT
