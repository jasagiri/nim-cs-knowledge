# State machine

## Intent
Put the allowed transitions in a table and let one function read it. A machine is a set of states, a set of inputs and rows (state, input, next state). Because the table is data, the same table answers other questions: which states can be reached, which are terminal, whether a pair has two rows. A forbidden input is a returned error that names the pair, never an exception and never a silent no-op.

## Use when / avoid when
- Use for lifecycles with a closed set of states: orders, connections, documents, parsers.
- Use when invalid transitions must be rejected explicitly and the rejection must be testable.
- Avoid when the next state depends on rich data rather than a small input alphabet; model that as a function (`functional_core.md`).
- For behaviour attached to transitions, return effect descriptions as in `functional_core.md`.

## Nim shape
`src/nimcs/patterns/state_machine.nim` models an order. `OrderState` and `Input` are enums; `transitions` is a constant list of `Transition` rows. `step(state, input)` returns `Result[OrderState, TransitionError]`; `run` folds `step` and stops at the first error; `reachable`, `allowedInputs`, `isTerminal` and `isDeterministic` are questions asked of the same table.

```nim
import nimcs/fp/result
import nimcs/patterns/state_machine

let delivered = run(osCreated, [inPay, inShip, inDeliver])
doAssert delivered.isOk
doAssert delivered.value == osDelivered
let refused = run(osCreated, [inShip])
doAssert refused.isErr
doAssert refused.error == TransitionError(state: osCreated, input: inShip)
doAssert reachable(osShipped) == @[osShipped, osDelivered]
```

## Laws and invariants
Why this is testable: `step` is total over (state, input), so a test can enumerate every pair, and `run` is a fold, so sequences are generated rather than hand-written.
- Every row of the table, stepped, goes to the row's target (PAT-STATEMACHINE-01).
- Every pair without a row is rejected with an error naming exactly that pair (PAT-STATEMACHINE-02).
- A successful `run` always ends in a state of `reachable(start)` (PAT-STATEMACHINE-03).
- A terminal state rejects every input (PAT-STATEMACHINE-04).
- The table is deterministic: no pair has two rows (PAT-STATEMACHINE-05).
- `run(a & b)` equals running `a` then `b`, and the error reported is the first invalid step (PAT-STATEMACHINE-06).

## Complexity
`step` is O(r) in the number of rows r (a linear scan; use an array indexed by state and input when r is large, for O(1)). `run` is O(n * r) for n inputs. `reachable` is O(s * r) in the number of states s.

## Pitfalls
Scattered conditionals with a catch-all `else` hide invalid input: the machine silently stays where it was and the bug surfaces far away.

```nim bad
func next(s: OrderState; i: Input): OrderState =
  if s == osCreated and i == inPay: osPaid
  elif s == osPaid and i == inShip: osShipped
  else: s
```

Keep the table as data and return the error:

```nim
import nimcs/fp/result
import nimcs/patterns/state_machine

doAssert step(osPaid, inShip).value == osShipped
doAssert step(osPaid, inPay).isErr
```

Also write `case` over the state enum without `else` when you must branch on it, so adding a state is a compile error where it is not handled.

## Related
- `functional_core.md`
- `cqrs.md` (a command side enforcing a lifecycle)
- `event_sourcing.md` (transitions recorded as events)
- `pipeline.md` (another composition of Result-returning steps)

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `1cbc332178e5a52f` Data-Oriented Design
