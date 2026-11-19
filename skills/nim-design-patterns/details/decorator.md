# Decorator

## Intent
Add behaviour around an object without changing it or its interface. The OO pattern wraps an
object in another object with the same interface. In Nim a handler is a proc value
(`Request -> Response`) and a decorator is a function from handler to handler, `proc(h: Handler):
Handler`. Stacking decorators is function composition.

## Use when / avoid when
- Use for cross-cutting behaviour around a core: authorisation, headers, tracing, retries, timing.
- Use `compose` and `stack` to build a pipeline from a list, outermost first.
- Avoid subclassing the core to add one behaviour: that multiplies classes per combination.
- Avoid decorators that need hidden state (a counter, a cache): make the state an explicit value
  (see `proxy.md`) or move it to the shell.

## Nim shape
The pipeline is pure: the "log" is a trace carried in the response. A decorator may call the inner
handler (`withTrace`), skip it (`withAuth` on a wrong token) or post-process its result
(`withBodySuffix`). `compose(a, b)(h)` is `a(b(h))`, so `a` sees the request first.

Module: `src/nimcs/patterns/decorator.nim`.

```nim
import nimcs/patterns/decorator

let core: Handler = proc(r: Request): Response {.noSideEffect, raises: [].} =
  Response(status: 200, body: "hello " & r.path, trace: @["core"])

let app = stack(@[withTrace("outer"), withAuth("secret"), withBodySuffix("!")])(core)

let ok = app(Request(path: "x", token: "secret"))
doAssert ok.body == "hello x!"
doAssert ok.trace == @["outer", "core", "outer/done"]

let denied = app(Request(path: "x", token: "no"))
doAssert denied.status == 401 and "core" notin denied.trace
```

## Laws and invariants
- `compose(a, b)` applied to a handler is `a(b(h))`: the outer decorator's trace entries come first
  and last (GOF-DECORATOR-01).
- The identity decorator changes nothing, alone or composed on either side (GOF-DECORATOR-02).
- `compose` is associative on behaviour, and `stack` puts the first element outermost
  (GOF-DECORATOR-03).
- An authorisation decorator gives 401 for a wrong token without running the inner handler, and is
  transparent for the right one (GOF-DECORATOR-04).

## Complexity
Each decorator adds one closure allocation when the pipeline is built and one indirect call per
request. Build the pipeline once and reuse it.

## Pitfalls
Order matters, and `compose` is not commutative: authorising after tracing logs the denied request,
authorising before it does not.

```nim bad
# Looks symmetrical, behaves differently: do not assume you can reorder decorators freely.
let a = stack(@[withAuth("k"), withTrace("t")])
let b = stack(@[withTrace("t"), withAuth("k")])
```

State the intended order in one place and test it:

```nim
import nimcs/patterns/decorator

let core: Handler = proc(r: Request): Response {.noSideEffect, raises: [].} =
  Response(status: 200, body: "", trace: @[])
let authFirst = stack(@[withAuth("k"), withTrace("t")])(core)
let traceFirst = stack(@[withTrace("t"), withAuth("k")])(core)
let bad = Request(path: "p", token: "x")
doAssert authFirst(bad).trace.len == 0
doAssert traceFirst(bad).trace == @["t", "t/done"]
```

## Related
- `proxy.md` (a wrapper that controls access to one object), `adapter.md`, `composite.md`, `strategy.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `25f90d554113e6d5` Scala & Design Patterns: Exploring Language Expressivity
- `0789f21330e7f72a` Source Making Design Patterns and UML
- `690b10bb5f31ac02` The Catalog of Design Patterns
