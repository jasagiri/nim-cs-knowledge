# Idempotence

## Intent
An operation is idempotent when doing it twice has the same effect as doing it once: `f(f(x)) == f(x)`. That is what makes retries safe. A client that does not know whether its request arrived can send it again; a store that merges a set, upserts by key, or applies a command identified by an idempotency key ends in the same state either way. The idea is a law, so it is tested as a property.

## Use when / avoid when
- Use for normal forms (trim, canonical case, sorted unique), set insertion, upsert by key, and any command that may be delivered more than once.
- Use an idempotency key for operations that are not naturally idempotent (a payment, a counter increment): record the key, ignore a repeat.
- Avoid claiming idempotence for "add 1" or "append": they change the result every time.
- Avoid one global "seen" set shared by unrelated operations; keep the keys with the state they guard.

## Nim shape
`src/nimcs/fp/idempotence.nim`: `normalizeSpaces`, `setInsert`, `upsertByKey`, a `Ledger` with `apply(command)` returning a `Result`, and the checker `isIdempotentAt`.

```nim
import nimcs/fp/idempotence

import nimcs/fp/result

let once = initLedger().apply(Command(key: "pay-7", amount: 50))
let retried = once.value.apply(Command(key: "pay-7", amount: 50))
doAssert once == retried                       # same command again: a retry, same ledger
doAssert once.value.apply(Command(key: "pay-7", amount: 99)).error == keyConflict

let batch = @[Command(key: "a", amount: 1), Command(key: "b", amount: 2)]
doAssert initLedger().applyAll(batch & batch) == initLedger().applyAll(batch)
doAssert isIdempotentAt(normalizeSpaces, "  a   b ")
```

The state transition is a pure function: old ledger in, new ledger out. The keys are stored sorted, so the result does not depend on hash order.

## Laws and invariants
- `normalizeSpaces` applied twice equals once (FP-IDEMPOTENCE-01).
- `setInsert` is idempotent and keeps the set sorted and unique (FP-IDEMPOTENCE-02).
- `upsertByKey` is idempotent and leaves exactly one entry for the key, even when the input already had duplicates of it (FP-IDEMPOTENCE-03).
- The same command (same key, same amount) applied again changes nothing (FP-IDEMPOTENCE-04); the same key with a different amount is reported as `keyConflict`, never silently ignored, because it is a client bug and not a retry (FP-IDEMPOTENCE-09). `patterns/idempotent_command.md` extends this with stored responses.
- Replaying a whole batch after itself gives the ledger of one run (FP-IDEMPOTENCE-05).
- Commands with distinct keys commute: any permutation gives the same ledger (FP-IDEMPOTENCE-06).
- Determinism is not idempotence: `x + 1` fails the law and the checker says so (FP-IDEMPOTENCE-07).
- `abs`, `clamp` and `sorted` are idempotent (FP-IDEMPOTENCE-08).

## Complexity
`normalizeSpaces` is O(n). `setInsert` and `apply` find the position in O(log n) and rebuild the sequence in O(n). `upsertByKey` is O(n). For large state use a persistent map or a set structure from the `ds` area.

## Pitfalls
A retry that repeats a non-idempotent effect applies it twice.

```nim bad
proc deposit(balance: var int; amount: int) =
  balance += amount            # a retried request pays twice
```

```nim
import nimcs/fp/idempotence
import nimcs/fp/result

let key = "request-42"

let first = initLedger().apply(Command(key: key, amount: 10))
let retry = first.value.apply(Command(key: key, amount: 10))
doAssert retry.isOk and retry.value.balance == 10
```

Also: the key must come from the request (client-chosen or derived from its content), not be generated per attempt; a fresh key per retry defeats the guard. Keys must also be kept as long as retries can arrive.

## Related
`immutable_update.md`, `monoid.md` (idempotent monoids such as max and set union tolerate duplicates), `smart_constructor.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `3e3407367a2d5466` RFC 9110: HTTP Semantics
- `f6c5d8cfc5500f9b` The Idempotency-Key HTTP Header Field (IETF draft)
