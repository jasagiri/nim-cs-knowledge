# Supervisor

## Intent
Let it crash: a worker does not defend against every failure, and when it dies its supervisor decides what to bring back. The decision is a pure function `onExit(policy, history, child, reason, now): Decision` of values: a policy (strategy, children in start order, restart intensity), the times of earlier restarts, the child that exited and why. The strategies are one_for_one, one_for_all and rest_for_one, and a restart intensity limit says at most N restarts within a window of T ticks. Time is data (`now` is a tick the host passes in; there is no clock inside), so the decision replays exactly and the limit is testable.

## Use when / avoid when
- Use for long-lived workers that can fail independently (connections, sessions, pipeline stages) and whose failure should be handled by restarting, not by every caller.
- Use with `actor.md`: the host delivers an actor's exit to its supervisor as a message and performs the decision (stop the targets in reverse start order, start them in start order).
- Use instead of `retry_backoff.md` when the thing that failed is a running party with state, not a single call you can repeat; use instead of `state_machine.md` when the transitions are "who restarts whom", not business states.
- Avoid for a failure you can handle where it happens: return a `Result` (`smart_constructor` in nim-functional-core, `functional_core.md`) and keep crashes for what you did not expect.
- Avoid a restart limit that is never reached in tests: the escalation path is the part that saves you from a restart storm.

## Nim shape
The module is `src/nimcs/patterns/supervisor.nim`. `Policy` is sealed: `initPolicy(strategy, children, maxRestarts, window)` returns a `Result` and rejects a negative intensity, a window under 1 tick, an empty or duplicate child id. `ChildSpec` has a `RestartKind`: permanent (always restarted), transient (only after a crash), temporary (never, and not restarted as a sibling either). `onExit` returns `Result[Decision, ExitError]` (`ueUnknownChild` for an id that is not in the policy). A `Decision` is `dkIgnore`, `dkRestart` with `targets` in start order, or `dkEscalate` with every child as `targets`; each carries the `History` to pass to the next call.

```nim
import nimcs/fp/result
import nimcs/patterns/supervisor

let kids = @[
  ChildSpec(id: "db", restart: rkPermanent),
  ChildSpec(id: "cache", restart: rkPermanent),
  ChildSpec(id: "web", restart: rkTransient)]
let policy = initPolicy(stRestForOne, kids, 3, 60).value
let d = policy.onExit(noHistory(), "cache", erCrash, 100).value
doAssert d.kind == dkRestart
doAssert d.targets == @["cache", "web"]     # the child and those started after it; "db" is untouched
```

The limit is on restarts, not on crashes: the fourth restart inside one window escalates, and the supervisor's own parent decides next.

```nim
import nimcs/fp/result
import nimcs/patterns/supervisor

let policy = initPolicy(stOneForOne, @[ChildSpec(id: "db", restart: rkPermanent)], 3, 60).value
var history = noHistory()
var escalatedAt = -1
for tick in [10, 11, 12, 13, 14]:
  let d = policy.onExit(history, "db", erCrash, tick).value
  if d.kind == dkEscalate and escalatedAt < 0: escalatedAt = tick
  history = d.history
doAssert escalatedAt == 13                   # restarts at 10, 11, 12 were allowed (N = 3)
```

## Laws and invariants
- one_for_one restarts exactly the child that exited (PAT-SUPERVISOR-01).
- one_for_all restarts every child in start order, except temporary siblings (PAT-SUPERVISOR-02).
- rest_for_one restarts the child and the children started after it in start order; earlier ones are untouched (PAT-SUPERVISOR-03).
- Permanent always restarts, transient only after a crash, temporary never; an ignored exit leaves the history as it was (PAT-SUPERVISOR-04).
- The N+1th restart within T ticks escalates; crashes at least T ticks apart never do; N = 0 escalates on the first (PAT-SUPERVISOR-05).
- The history stays ascending and never longer than N, and escalation targets every child (PAT-SUPERVISOR-06).
- Bad policies and unknown children are errors, and the `Policy` fields are not writable outside the module (PAT-SUPERVISOR-07).
- The same inputs give the same decision (PAT-SUPERVISOR-08).

## Complexity
`onExit` is O(c + h) for c children and h remembered restarts (h is at most N after pruning). The history is a small sorted `seq`; it is copied per call.

## Pitfalls
A supervisor that reads the clock and keeps its restart count in a variable:

```nim bad
import std/times

var restarts = 0
var windowStart = epochTime()

proc onChildDied(name: string) =
  if epochTime() - windowStart > 60.0:
    restarts = 0                      # the limit depends on when the test happens to run
    windowStart = epochTime()
  inc restarts
  if restarts > 3: quit(1)            # escalation by exiting the process
```

Fix: pass the tick and the history in, return a `Decision`, and let the host act on it. Do not restart without a limit (a worker that crashes at once restarts forever), and do not count crashes that need no restart (a transient child that exited normally is `dkIgnore`).

## Related
- `actor.md` (what is supervised; the host delivers exits as messages)
- `retry_backoff.md` (repeating a call; the same "time as data" idea)
- `state_machine.md` (transitions as data)
- `idempotent_command.md` (restarted workers see redelivered work)
- `smart_constructor` in nim-functional-core (why `initPolicy` returns a `Result`)

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `1b179470b870e5fe` Erlang/OTP: Supervisor Behaviour
- `f2b0c2a6b0908171` Making reliable distributed systems in the presence of software errors (Armstrong thesis)
