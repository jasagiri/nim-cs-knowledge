## Decorator as a function from handler to handler.
##
## The OO pattern adds behaviour to an object by wrapping it in another object with the same
## interface. In Nim a handler is a proc value `Request -> Response` and a decorator is
## `proc(h: Handler): Handler`; stacking decorators is function composition. Use it for
## cross-cutting behaviour (headers, authorisation, tracing) around a core handler without
## changing the core. The pipeline is pure: there is no I/O, the "log" is a trace in the response.

type
  Request* = object
    path*: string
    token*: string

  Response* = object
    status*: int
    body*: string
    trace*: seq[string]

  Handler* = proc(r: Request): Response {.noSideEffect, raises: [].}
  Decorator* = proc(h: Handler): Handler {.noSideEffect, raises: [].}

func identityDecorator*(): Decorator {.raises: [].} =
  proc(h: Handler): Handler {.noSideEffect, raises: [].} = h

func withTrace*(label: string): Decorator {.raises: [].} =
  ## Records `label` before the inner handler runs and again, as `label/done`, after it returns.
  proc(h: Handler): Handler {.noSideEffect, raises: [].} =
    proc(r: Request): Response {.noSideEffect, raises: [].} =
      var res = h(r)
      res.trace = @[label] & res.trace & @[label & "/done"]
      res

func withAuth*(expected: string): Decorator {.raises: [].} =
  ## Short-circuits with 401 when the token differs; the inner handler is not called.
  proc(h: Handler): Handler {.noSideEffect, raises: [].} =
    proc(r: Request): Response {.noSideEffect, raises: [].} =
      if r.token == expected:
        h(r)
      else:
        Response(status: 401, body: "unauthorized", trace: @[])

func withBodySuffix*(suffix: string): Decorator {.raises: [].} =
  proc(h: Handler): Handler {.noSideEffect, raises: [].} =
    proc(r: Request): Response {.noSideEffect, raises: [].} =
      var res = h(r)
      res.body.add(suffix)
      res

func compose*(outer, inner: Decorator): Decorator {.raises: [].} =
  ## `compose(a, b)(h)` is `a(b(h))`: `a` is the outermost wrapper and sees the request first.
  proc(h: Handler): Handler {.noSideEffect, raises: [].} =
    outer(inner(h))

func stack*(ds: seq[Decorator]): Decorator {.raises: [].} =
  ## The first element is the outermost decorator.
  var acc = identityDecorator()
  for i in countdown(ds.high, 0):
    acc = compose(ds[i], acc)
  acc
