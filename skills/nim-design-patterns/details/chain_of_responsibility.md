# Chain of Responsibility

## Intent
A request should be handled by the first of several candidates that is willing, without the sender knowing which. The OO pattern links handler objects, each holding its successor. In functional Nim a handler is `proc(request): Option[Response]` and a chain is a plain `seq` of them: "pass it on" is moving to the next element and the answer is the first `some`. The linked structure disappears.

## Use when / avoid when
- Use for approvals by authority, middleware, parsers that try alternatives, fallbacks (cache, then disk, then network), validation rules where the first failing rule answers.
- Use `orElse` to build handlers in pieces: it is associative with `never` as identity, so chains nest freely.
- Avoid when every handler must run (that is a pipeline or `observer`).
- Avoid when the handler choice is a simple lookup by key: use a table.

## Nim shape
The module is `src/nimcs/patterns/chain_of_responsibility.nim`, with an expense-approval example. `Handler[Req, Resp]` is a pure proc type. `firstSome(chain, request)` asks in order and stops at the first answer; `handle` turns "nobody answered" into `err(Unhandled)`. `within(name, limit)` builds a handler; `authorityChain()` is clerk (up to 100), manager (up to 1000), director (up to 10000).

```nim
import nimcs/fp/result
import nimcs/patterns/chain_of_responsibility

let chain = authorityChain()
doAssert chain.handle(Claim(amount: 100, category: "meals")).value.by == "clerk"
doAssert chain.handle(Claim(amount: 101, category: "meals")).value.by == "manager"
doAssert chain.handle(Claim(amount: 50000, category: "travel")).isErr
```

Handlers combine like functions, and a handler can be narrowed without touching its code:

```nim
import std/options
import nimcs/patterns/chain_of_responsibility

let meals = within("clerk", 100).onlyCategory("meals")
let both = meals.orElse(within("manager", 1000))
doAssert both(Claim(amount: 50, category: "meals")).get.by == "clerk"
doAssert both(Claim(amount: 50, category: "travel")).get.by == "manager"
doAssert both(Claim(amount: 5000, category: "meals")).isNone
```

## Laws and invariants
- `firstSome` returns the answer of the first handler that answers (GOF-CHAIN-01).
- An empty chain, or one where nobody accepts, is an `Unhandled` error (GOF-CHAIN-02).
- Appending handlers never changes an answer already given (GOF-CHAIN-03).
- The lowest authority whose limit covers the amount approves, limits inclusive (GOF-CHAIN-04).
- `orElse` is associative (GOF-CHAIN-05) and `never` is its identity (GOF-CHAIN-06).
- Handling is deterministic (GOF-CHAIN-07); a category-restricted handler passes other categories on (GOF-CHAIN-08).

## Complexity
`firstSome` is O(h) handler calls in the worst case for h handlers and stops at the first answer, so the cost depends on how early the answering handler sits (order cheap or common handlers first). `orElse` allocates one closure per combination; deeply nested `orElse` adds one call frame per level.

## Pitfalls
Handlers that hold a mutable `next` pointer and forget to forward (the request silently dies), or that return a default response instead of "not mine":

```nim bad
type Handler = ref object
  next: Handler
  limit: int

proc handle(h: Handler; amount: int): string =
  if amount <= h.limit: "approved"
  else: h.next.handle(amount)     # nil dereference at the end of the chain
```

Fix: the chain is a `seq` and the end of the chain is the end of the loop; the result type (`Option`, `Result[_, Unhandled]`) makes "nobody handled it" a value the caller must deal with. Another trap: order dependence that nobody wrote down; the first matching handler wins, so list the narrowest handler first and test the order (as GOF-CHAIN-04 does).

## Related
- `strategy.nim` (picking one implementation, instead of trying several)
- `interpreter.nim` (rules as data)
- `../../nim-functional-core` (`Option`, `Result`)

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `25f90d554113e6d5` Scala & Design Patterns: Exploring Language Expressivity
- `0789f21330e7f72a` Source Making Design Patterns and UML
- `690b10bb5f31ac02` The Catalog of Design Patterns
