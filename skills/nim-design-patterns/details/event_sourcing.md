# Event sourcing

## Intent
Store what happened, not what is true now. The state of an entity is the fold of its events: start from an empty state and apply each event in order. The log only grows; a past state is a prefix of the fold; a snapshot is a saved intermediate value that lets you skip the prefix.

## Use when / avoid when
- Use when history matters (audit trail, undo, "what was the balance last Tuesday") or when several views must be derived from the same facts.
- Use when you want to rebuild state after a bug fix by replaying.
- Avoid when only the current value matters and nobody will ask how it came about; a plain record is simpler.
- To refuse invalid changes before they become facts, put a command side in front (`cqrs.md`); events themselves are never refused.

## Nim shape
`src/nimcs/patterns/event_sourcing.nim` has `Event` (a kind and a positive amount), `Account` (balance and version) and four functions: `apply` is one fold step, `replay` is the whole fold, `replayFrom` continues from a snapshot, `snapshotAt` replays a prefix. The log is a `seq[Event]` and `appended` returns a longer copy.

```nim
import nimcs/patterns/event_sourcing

let log = @[deposited(100), withdrawn(30), deposited(5)]
let full = replay(log)
let snap = snapshotAt(log, 2)
doAssert full == Account(balance: 75, version: 3)
doAssert replayFrom(snap, log[2 .. ^1]) == full
doAssert log.appended(withdrawn(5)).len == 4
doAssert log.len == 3
```

## Laws and invariants
Why this is testable: `apply` is a pure function and `replay` a fold, so every claim about history is an equation between two folds that a generator of event lists can attack.
- Appending an event and replaying equals applying the event to the old state; replay is deterministic (PAT-EVENTSOURCING-01).
- Snapshot plus tail equals full replay, for every cut (PAT-EVENTSOURCING-02).
- The version equals the number of events and the balance equals deposits minus withdrawals (PAT-EVENTSOURCING-03).
- Appending leaves the old log unchanged (PAT-EVENTSOURCING-04).
- `snapshotAt` at 0 or below is the empty account, and beyond the end is the full replay (PAT-EVENTSOURCING-05).

## Complexity
`replay` is O(n) time and O(1) extra space for n events. `replayFrom` with a snapshot costs O(tail). `appended` is O(n) here because it copies the `seq`; a persistent queue (`bankers_queue.md`) makes it amortized O(1) when logs are long.

## Pitfalls
Keeping only the current number throws the history away; no replay, no audit, no snapshot is possible afterwards.

```nim bad
var balance = 0
proc deposit(n: int) = balance += n
```

Record the fact and derive the number:

```nim
import nimcs/patterns/event_sourcing

let log = @[deposited(10)]
doAssert replay(log).balance == 10
```

Another trap is an `apply` that reads the clock or calls a service: replay then gives a different state each time. Put the timestamp inside the event when the event is created, and keep `apply` free of anything but its two arguments.

## Related
- `cqrs.md` (commands decide events; read models fold them)
- `idempotent_command.md` (deduplicating the commands that produce events)
- `functional_core.md`
- `bankers_queue.md` (an append-friendly persistent log)

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `cdbf277d93825bc0` Designing Event-Driven Systems. Concepts and Patterns for Streaming Services with Apache Kafka
- `5009e42d6ca146f2` Exploring CQRS and Event Sourcing
