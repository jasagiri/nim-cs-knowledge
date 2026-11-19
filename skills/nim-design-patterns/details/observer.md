# Observer

## Intent
Several parties must react when something happens. The OO pattern keeps a mutable list of callback objects in a subject and calls each one on change, which hides ordering, mutation and re-entrancy. In functional Nim the subject is gone: an event is a value, the state is a value, and each subscriber is a named pure reducer `proc(state, event): state`. Publishing is a left fold of the subscribers over the state, in subscription order, and the subscriber list is itself an immutable value.

## Use when / avoid when
- Use for reactive models: UI state, projections of an event log, audit trails, metrics derived from events.
- Use when you want to reproduce a state from a log of events (replay) or test reactions without callbacks.
- Avoid when a subscriber must perform I/O: keep the reducers pure and let the program's edge read the new state after `publish` and do the I/O there.
- Avoid when there is a single reaction: call a function.

## Nim shape
The module is `src/nimcs/patterns/observer.nim`. `Bus[S, E]` holds `Subscription`s (an id and a `Reducer[S, E]`). `subscribe` appends (or replaces the same id in place), `unsubscribe` removes by id, both returning a new bus. `publish(bus, state, event)` folds the reducers; `replay` publishes a log in order.

```nim
import nimcs/patterns/observer

type Counts = object
  total: int
  evens: int

func countAll(c: Counts; e: int): Counts {.raises: [].} =
  Counts(total: c.total + 1, evens: c.evens)

func countEvens(c: Counts; e: int): Counts {.raises: [].} =
  Counts(total: c.total, evens: c.evens + (if e mod 2 == 0: 1 else: 0))

let bus = initBus[Counts, int]()
  .subscribe("all", countAll)
  .subscribe("evens", countEvens)
let after = bus.replay(Counts(), [1, 2, 4, 7])
doAssert after.total == 4
doAssert after.evens == 2
```

Subscribers see what earlier ones wrote, so order is a visible contract; removal is a value too:

```nim
import nimcs/patterns/observer

func addOne(s: int; e: string): int {.raises: [].} = s + 1
func dbl(s: int; e: string): int {.raises: [].} = s * 2

let bus = initBus[int, string]().subscribe("add", addOne).subscribe("dbl", dbl)
doAssert bus.publish(5, "go") == 12            # (5 + 1) * 2
doAssert bus.unsubscribe("add").publish(5, "go") == 10
doAssert bus.ids == @["add", "dbl"]            # the original bus is intact
```

When the listeners are fixed (a port of `CounterListener` and `LogListener`), skip the bus: one
state record with a field per listener and one reducer. Use the bus when listeners are added and
removed while running. This form needs no import, so it also works outside this repository. The
`*` marks export the types, fields and functions, which a test in another file needs. `subscribe`
disappears (each listener is a field), `publish` becomes `step`, and a field named after a Nim
keyword (`type`) is renamed (`kind`):

```nim
type
  Event* = object
    kind*, payload*: string
  Listeners* = object
    clicks*: int          # was CounterListener
    log*: seq[string]     # was LogListener

func step*(s: Listeners; e: Event): Listeners {.raises: [].} =
  result = s
  if e.kind == "Click": inc result.clicks
  result.log.add e.kind & ":" & e.payload

func replay*(events: openArray[Event]): Listeners {.raises: [].} =
  for e in events: result = result.step(e)

let events = [Event(kind: "Click", payload: "a"), Event(kind: "Key", payload: "x")]
doAssert replay(events).clicks == 1
doAssert replay(events) == replay(events)
```

## Laws and invariants
- Replaying one log twice from the same state gives equal states (GOF-OBSERVER-01).
- `publish` is the fold of the subscribers in subscription order (GOF-OBSERVER-02); with no subscribers the state is unchanged (GOF-OBSERVER-03).
- `unsubscribe` removes exactly one subscriber and keeps the rest in order; unknown ids change nothing (GOF-OBSERVER-04).
- Replaying two logs in two steps equals replaying their concatenation (GOF-OBSERVER-05).
- Re-subscribing an id replaces it in place and never runs it twice (GOF-OBSERVER-06); the ticker example shows latest, high, count and audit (GOF-OBSERVER-07).

## Complexity
`publish` is O(s) reducer calls for s subscribers (plus what the reducers do); `replay` is O(e s) for e events. `subscribe` and `unsubscribe` are O(s) and copy the subscriber list. Reducers that copy a large state per event cost O(state); keep the state small or structurally shared.

## Pitfalls
A global mutable list of callbacks, called from wherever the change happens:

```nim bad
var listeners: seq[proc(e: int)]

proc notify(e: int) =
  for l in listeners: l(e)     # order, re-entrancy and removal during the loop are all implicit

proc subscribe(l: proc(e: int)) = listeners.add l
```

Fix: a `Bus` value passed explicitly, reducers that return the new state, and `publish` as the single place events are folded. Also keep reducer order stable and documented (here: subscription order); never build the subscriber list by iterating a hash table.

## Related
- `command.nim` (commands are the events; `apply` is the reducer)
- `state.nim` (a single reducer with a transition table)
- `mediator.nim` (routing rules between named parties)

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `25f90d554113e6d5` Scala & Design Patterns: Exploring Language Expressivity
- `0789f21330e7f72a` Source Making Design Patterns and UML
- `690b10bb5f31ac02` The Catalog of Design Patterns
