# State

## Intent
An object behaves differently depending on its mode, and `if`s on mode flags spread through every method. The OO pattern gives each mode a class. In functional Nim the modes are the cases of one object variant, so a field such as `credit` exists only where it means something, and behaviour is a pure transition `step(state, event): Result[state, Error]`: an exhaustive `case` on the phase, then on the event. An event the current mode does not accept is an error value and the state stays as it was.

## Use when / avoid when
- Use for protocols, workflows, UI modes, device controllers, order lifecycles: anything with named modes and events that mean different things in each.
- Use when "invalid state" bugs appear (a `bool` flag set while a field is stale): the variant makes those states unrepresentable.
- Avoid when there are two modes and one event: a `bool` or an enum field is enough.
- Avoid for pure data transformations without modes: that is a function pipeline.

## Nim shape
The module is `src/nimcs/patterns/state.nim`: a one-product vending machine priced in yen. `Machine` has counters common to all phases and a variant part: idle, holding credit, or returning change. `step` decides every (phase, event) pair explicitly; `run` folds a list of events, keeping the machine on rejection and listing each rejection with its index. `invariantHolds` states money conservation: inserted money equals sold items times the price, plus money handed back, plus money still held.

```nim
import nimcs/fp/result
import nimcs/patterns/state

let rep = newMachine(2).run([coin(100), coin(50), select()])
doAssert rep.machine.phase == pReturning
doAssert rep.machine.change == 30
doAssert rep.machine.stock == 1
let done = rep.machine.step(collect()).value
doAssert done.phase == pIdle
doAssert done.invariantHolds
```

Wrong events are values, not crashes:

```nim
import nimcs/fp/result
import nimcs/patterns/state

let m = newMachine(1).step(coin(100)).value
doAssert m.step(select()).error == veInsufficient
doAssert m.step(restock(5)).error == veNotIdle
doAssert m.step(coin(7)).error == veBadCoin
let rep = m.run([collect(), coin(50), select()])
doAssert rep.rejected == @[(0, veNothingToCollect)]
doAssert rep.machine.phase == pReturning
```

## Laws and invariants
- Money conservation and non-negative counts hold after every accepted event, for any event sequence (GOF-STATE-01).
- A rejected event leaves the machine unchanged and is listed with its index (GOF-STATE-02); running twice gives equal reports (GOF-STATE-03).
- Insert 100 and 50, select: one item sold, 30 yen in the tray (GOF-STATE-04); too little credit gives `veInsufficient` (GOF-STATE-05).
- While change is in the tray only collect is accepted (GOF-STATE-06); a sold-out machine refuses coins (GOF-STATE-07).
- A refund returns the whole credit and sells nothing (GOF-STATE-08); unknown coins and similar misuse have their own errors (GOF-STATE-09).

## Complexity
`step` is O(1) (a `case` and a record copy). `run` is O(e) for e events and keeps O(r) for r rejections. The variant stores only the fields of the current phase.

## Pitfalls
A phase flag next to fields that are only valid in some phases:

```nim bad
type Machine = object
  hasCredit: bool
  credit: int          # meaningless when hasCredit is false
  returning: bool      # can be true together with hasCredit
```

Fix: one variant with one case per phase, as `Machine` does; the invalid combination cannot be built. Related traps: `else` branches in the transition `case` (a new event or phase would be silently accepted or ignored; list every case), and "fixing" a rejected event by clamping or ignoring it silently; return the error and let the caller decide, as `run` does by recording it.

## Related
- `command.nim` (events as data with a pure `apply`)
- `observer.nim` (several reducers over one event stream)
- `memento.nim` (keeping earlier states)
- `interpreter.nim` (the same exhaustive-`case` discipline over a tree)

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `25f90d554113e6d5` Scala & Design Patterns: Exploring Language Expressivity
- `0789f21330e7f72a` Source Making Design Patterns and UML
- `690b10bb5f31ac02` The Catalog of Design Patterns
