# Dependency record (dependency injection by passing a record of procs)

## Intent
Business logic that needs the clock and a mail sender takes them as one argument, a record whose fields are procs. Production builds the record from the real procs; a test builds another from a fixed clock and a sender that appends to a list. No interface type, no mocking framework, no global to reset between tests.

## Use when / avoid when
- Use for the handful of effects a unit needs: time, randomness, a sender, a store.
- Use when a test double should be a few lines of ordinary code.
- Avoid when the order and content of effects must be inspected, rewritten or replayed; make the program data (`free_interpreter.md`).
- Avoid passing a record with dozens of fields; split it per use case so each routine sees only what it needs.

## Nim shape
`src/nimcs/patterns/dependency_record.nim`. `Clock` and `Sender` are proc types annotated `raises: []`; a failing send is a `Result`, not an exception. `Deps` holds one of each. `withClock` and `withSender` return a copy with one field replaced. `remindOverdue` is a `proc`, not a `func`, because a record it is given may perform effects; its doc comment says so.

```nim
import nimcs/fp/result
import nimcs/patterns/dependency_record

proc main() =
  var outbox: seq[string]
  let deps = Deps(
    now: proc(): int {.raises: [].} = 10,
    send: proc(to, body: string): Result[int, string] {.raises: [].} =
      outbox.add to & ": " & body
      ok(outbox.len, string))
  let r = remindOverdue(deps, [Invoice(id: 7, customer: "ann", dueDay: 3, paid: false)])
  doAssert r.isOk
  doAssert r.value == @[1]
  doAssert outbox == @["ann: Invoice 7 was due on day 3"]

main()
```

The production record reads the real clock; a real sender would call a mail client and turn its failure into `err`:

```nim
import std/times
import nimcs/fp/result
import nimcs/patterns/dependency_record

proc liveDeps(): Deps =
  Deps(
    now: proc(): int {.raises: [].} = int(getTime().toUnix div 86_400),
    send: proc(to, body: string): Result[int, string] {.raises: [].} =
      err(int, "no mail server configured in this example"))

doAssert liveDeps().now() > 0
```

## Laws and invariants
Why this is testable: every effect enters through an argument, so a test supplies recording fakes and asserts on what they saw, and a property can generate the invoices.
- One message per unpaid invoice due before today, in list order, with the documented text, and the returned ids are the sender's (PAT-DEPENDENCYRECORD-01).
- The first failing send stops the run; the `RemindError` returned carries the sender's reason and the ids already sent (a sent message cannot be taken back), and no later invoice is tried (PAT-DEPENDENCYRECORD-02).
- `withClock` changes only the clock; paid and not-yet-due invoices are never sent (PAT-DEPENDENCYRECORD-03).
- Same inputs and equivalent fakes give equal results and messages (PAT-DEPENDENCYRECORD-04).

## Complexity
One pass over the invoices: O(n) calls of `send`. The record adds one indirect call per effect and no allocation beyond the closures.

## Pitfalls
A global client that the function reaches for makes every test depend on shared state.

```nim bad
var smtp: SmtpClient
proc remindOverdue(invoices: seq[Invoice]) =
  for inv in invoices:
    smtp.send(inv.customer, "overdue")
```

Pass the dependency in:

```nim
import nimcs/fp/result
import nimcs/patterns/dependency_record

let silent = Deps(
  now: proc(): int {.raises: [].} = 0,
  send: proc(to, body: string): Result[int, string] {.raises: [].} = ok(0, string))
doAssert remindOverdue(silent, newSeq[Invoice]()).value.len == 0
```

Do not annotate the logic `func` when the record's procs have effects; the compiler will refuse, and the honest signature (`proc`) tells callers where the effects are.

## Related
- `free_interpreter.md` (injecting by interpreter instead of by record)
- `functional_core.md` (keeping decisions out of effectful code)
- `pipeline.md`
- `retry_backoff.md` (the shell loop that would call a `Sender`)

## Sources

None in the catalog: no table of contents among the 450 core sources examined so far (catalog/concepts.json) names this concept.
