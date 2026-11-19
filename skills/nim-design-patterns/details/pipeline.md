# Pipeline (middleware as composition)

## Intent
A `Handler` turns a request into a response or an error. A `Middleware` takes a handler and returns a handler: it can refuse before calling the inner one, change what comes back, or pass it through. Stacking middleware is function composition, so a stack has the algebra of composition: associative, with an identity.

## Use when / avoid when
- Use for cross-cutting steps in front of a handler: authentication, size limits, tagging, timing, error mapping.
- Use when you want each step tested alone and the order of steps stated in one list.
- Avoid when steps share mutable state across requests; that belongs in the shell around the pipeline.
- For steps that transform a value without an outer handler, plain `Result` chaining (`flatMap` in `result.nim`) is enough.

## Nim shape
`src/nimcs/patterns/pipeline.nim`. `Handler` is `proc(req): Result[Response, HttpError]` with `noSideEffect, raises: []`; `Middleware` is `proc(next: Handler): Handler`. `identity()` passes through, `andThen(outer, inner)` composes, `compose(list)` folds a list with the first element outermost. `requireUser`, `limitBody` and `tagged` are example middlewares.

```nim
import nimcs/fp/result
import nimcs/patterns/pipeline

func hello(req: Request): Result[Response, HttpError] {.raises: [].} =
  ok(Response(status: 200, body: "hello " & req.user), HttpError)

let app = compose([requireUser(), limitBody(10), tagged("v1")])(Handler(hello))
doAssert app(Request(path: "/", user: "ann", body: "")).value.body == "v1>hello ann"
doAssert app(Request(path: "/", user: "", body: "")).error.status == 401
doAssert app(Request(path: "/", user: "ann", body: "01234567890")).error.status == 413
```

## Laws and invariants
Why this is testable: handlers are pure, so two stacks are equal exactly when they answer every request the same way, and a property test can generate stacks and requests and compare.
- `identity` leaves a handler's answer unchanged (PAT-PIPELINE-01).
- `andThen` is associative (PAT-PIPELINE-02), and `identity` is its left and right unit (PAT-PIPELINE-03).
- A refusing middleware short-circuits: the answer does not depend on what lies behind it (PAT-PIPELINE-04).
- In `compose`, the first middleware is outermost (PAT-PIPELINE-05).
- `compose(xs & ys)` behaves as `andThen(compose(xs), compose(ys))`; the empty list is `identity` (PAT-PIPELINE-06).

## Complexity
Building a stack of m middlewares is O(m); each request passes through m closure calls, O(m) per request plus the handler. Closures allocate once per stack construction, not per request.

## Pitfalls
A global registry makes the order depend on who registered first and lets tests leak into each other.

```nim bad
var middlewares: seq[Middleware]
proc use(m: Middleware) = middlewares.add m
```

Build the stack from an explicit list:

```nim
import nimcs/fp/result
import nimcs/patterns/pipeline

func ok200(req: Request): Result[Response, HttpError] {.raises: [].} =
  ok(Response(status: 200, body: "ok"), HttpError)

let stack = compose([tagged("a"), tagged("b")])
doAssert stack(Handler(ok200))(Request(path: "", user: "", body: "")).value.body == "a>b>ok"
```

Another trap is a middleware that records timing or logs: that is an effect, and the `noSideEffect` type rejects it. Do such work in the shell around the outermost handler, or thread the data through the response.

## Related
- `state_machine.md` and `functional_core.md` (other Result-returning pure steps)
- `dependency_record.md`
- `decorator.md` and `chain_of_responsibility.md` (the GoF relatives)

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `234c8e8fafc08c50` Refactor Like a Superhero
