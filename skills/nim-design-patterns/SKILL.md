---
name: nim-design-patterns
description: >-
  Apply, translate or review a design pattern in Nim — the 23 GoF patterns and functional
  architecture patterns (functional core / imperative shell, event sourcing, CQRS, state machines,
  free and tagless-final interpreters, dependency records, middleware pipelines, idempotent
  commands, lenses, parser combinators, retry with backoff) and actor- and capability-based designs
  (actors, supervisors, request/reply, object capabilities, caretakers, sealer/unsealer) and refactoring and migration patterns (parallel change, strangler fig,
  branch by abstraction, anti-corruption layer, seam), executable specifications, small refactorings (replace conditional
  with polymorphism, decompose conditional, extract function, extract type, introduce parameter
  object) and architecture styles (layered architecture, model-view-update, load shedding) and resilience patterns (circuit breaker, bulkhead, token
  bucket, saga, transactional outbox) and the command buffer (a read pass that emits commands and a
  write pass that applies them, instead of changing a collection while looping over it, a copy of it
  or a `ref` per element). Use whenever Nim code reaches for
  classes, inheritance, `method`, callbacks, global singletons or mutable shared state, when a
  design is being ported from Java/C#/C++/Python, or when a request names a pattern. Shows what
  each pattern becomes in functional Nim, and which ones disappear.
---

# Design patterns in functional Nim

Most object-oriented patterns exist to work around missing language features: first-class
functions, sum types, value semantics, generics. Nim has all four, so a pattern either becomes a
smaller, more direct shape or disappears. Every pattern here has a tested module
`src/nimcs/patterns/<name>.nim` and a details page; read the page before using the pattern.

Inside this repository, import the module (`import nimcs/<area>/<name>`). In another project the
modules are not a published package: copy the shape from the details page into your own file, or
add this repository's `src/` to the compiler path (`--path:"<repo>/src"`). With that path set, importing is the default; copy
only when the task fixes a different signature. The `Result` in the pages is `nimcs/fp/result`: build it with
`ok(value, ErrorType)` and `err(ValueType, error)`, and read `.value` or `.error` only after `isOk` or `isErr`.

Your own task (a scratch directory, another project): the page's Public API section lists every
exported signature of its module. When the task fixes names, fields or a signature the module does
not have (`Payment(id, cents)` instead of `Command(key, amount)`), write your own types and routines
in your file from the page's shape and laws: the algorithm, the laws, the tests and the example's
layout (its fields and steps) carry over, the type and routine names do not (use the task's names:
`circle`, not the example's `square`). A formula the task fixes wins over a module law that differs
(a rounding direction); say the difference in the doc comment. An optional parameter of the source
(`pct?: number`) becomes `Option[T] = none(T)`. Do not convert between your types and the module's on every call;
a thin wrapper that only names the module's operations for the task (an `OrderedMap` over `hamt`, a
`TaskQueue` over `leftist_heap`) is fine. The
spec-row steps in this skill (`docs/spec`, `# SPEC:` lines, `tests/test_<area>_*.nim`) are for adding
a module to this repository; for your own code, put `std/unittest` tests with Given-When-Then names
in `test_<name>.nim` beside it, with no spec file. `propcheck` and `std/unittest` both define
`check`; they take different arguments, so both work in one file. A callback parameter of a
`func` is typed `proc(i: int): bool {.noSideEffect, raises: [].}`: add these pragmas to a fixed
signature that says `proc(i: int): bool`, since a `func` cannot call a callback that may have
effects or raise. Import only what the file uses (an unused import is a compile error under the
strict settings): `Option` needs `std/options`, `Result` needs `nimcs/fp/result`, and a file whose exported
routines return `Result` also writes `export result`, or a test that imports only that file fails
with "undeclared field: 'isErr'"; that test then needs no import of its own. Guard clauses with an early
`return err(...)` are fine in a `func`. A plain object (no `case`) gets `==` field by field, a sealed one (private fields,
`{.requiresInit.}`) included; an object variant does not. `opt.get` on
`none` is a defect, not an exception, so a `{.raises: [].}` func may call it after `isSome`. A `func`
may change its own `result` and its local variables (`result.log.add x`), never what its caller sees. When the file
uses `Result`, import it by default: if `import nimcs/fp/result` compiles (a prepared run directory's `nim.cfg` puts `src/` on the path),
use it. Only when it does not, copy this `Result` (the repository's adds `map`, `flatMap` and `==`):

```nim
type Result*[T, E] = object
  case isOk*: bool
  of true: value*: T
  of false: error*: E

func ok*[T, E](v: T; _: typedesc[E]): Result[T, E] {.raises: [].} = Result[T, E](isOk: true, value: v)
func err*[T, E](_: typedesc[T]; e: E): Result[T, E] {.raises: [].} = Result[T, E](isOk: false, error: e)
func isErr*[T, E](r: Result[T, E]): bool {.raises: [].} = not r.isOk

doAssert ok(3, string).value == 3 and err(int, "bad").isErr
```

## The translation table

| OO building block | Functional Nim |
|---|---|
| interface with one method | a proc type: `proc(x: A): B {.noSideEffect, raises: [].}` |
| interface with several methods | an object whose fields are procs (a *record of procs*) |
| class hierarchy over a closed set of cases | an object variant + exhaustive `case` (no `else`) |
| mutable object with setters | a value `object`; "setters" return a new value |
| callbacks registered on a subject | events as values, folded by pure reducers |
| `execute`/`undo` objects | commands as data + `apply(state, cmd): state` |
| global instance | a value passed as an argument (or an immutable `const`/`let`) |
| thread with a mutable inbox and handler | an actor: `step(self, state, msg)` returns the new state and effects as data; a host delivers one message at a time |
| restart-on-failure code with timers and counters | a supervisor: `onExit(policy, history, child, reason, now)` returns a decision; time is a tick argument |
| ambient authority (globals, role checks) | an object capability: a sealed value passed in, narrowed by attenuation |
| shared mutable "revoked" flag | a caretaker: revocation state is a value threaded through the calls |
| secret token or opaque handle | a sealer/unsealer pair over a sealed box |
| inheritance for reuse | a function taking the varying steps as arguments |

Rules (ADR-NCK-0002): no `method`, no `ref object of RootObj` hierarchies, no `converter`, no
global mutable state. Dynamic dispatch, when it is really needed, is a record of procs.

## Which pattern

| Problem | Pattern | Page |
|---|---|---|
| a family of related products chosen together | Abstract Factory → a record of constructor procs | [details/abstract_factory.md](details/abstract_factory.md) |
| many settings with cross-field rules | Builder → chained `func`s, `build` returns `Result` | [details/builder.md](details/builder.md) |
| an algorithm needs a product it should not know | Factory Method → a proc value or generic parameter | [details/factory_method.md](details/factory_method.md) |
| copy an existing configuration | Prototype → mostly disappears (values copy) | [details/prototype.md](details/prototype.md) |
| exactly one instance | Singleton → avoid; pass the value | [details/singleton.md](details/singleton.md) |
| two shapes that must meet | Adapter → a converting `func` | [details/adapter.md](details/adapter.md) |
| two dimensions that vary independently | Bridge → generics or a record of procs | [details/bridge.md](details/bridge.md) |
| part–whole trees | Composite → recursive variant + fold | [details/composite.md](details/composite.md) |
| add behaviour around a function | Decorator → `proc(f): proc` wrappers | [details/decorator.md](details/decorator.md) |
| hide a subsystem's steps | Facade → a module with a small export list | [details/facade.md](details/facade.md) |
| many equal values | Flyweight → interning in an explicit pool value | [details/flyweight.md](details/flyweight.md) |
| control access, cache, defer | Proxy → a record of procs wrapping another | [details/proxy.md](details/proxy.md) |
| first willing handler | Chain of Responsibility → list of `proc(req): Option[Resp]` | [details/chain_of_responsibility.md](details/chain_of_responsibility.md) |
| store, replay, undo requests | Command → data + pure `apply` | [details/command.md](details/command.md) |
| evaluate a small language | Interpreter → ADT + `eval` | [details/interpreter.md](details/interpreter.md) |
| walk a collection | Iterator → Nim `iterator` | [details/iterator_pattern.md](details/iterator_pattern.md) |
| many parties, central rules | Mediator → a pure routing function | [details/mediator.md](details/mediator.md) |
| snapshot and restore | Memento → old values (persistence makes it free) | [details/memento.md](details/memento.md) |
| react to happenings | Observer → events folded by reducers: listeners fixed in the code → one record and `step` (row below); listeners added and removed while running → the `Bus` | [details/observer.md](details/observer.md) |
| several stateful listeners on one event stream | one state record with a field per listener, one reducer `step(state, event)` | [details/observer.md](details/observer.md) |
| behaviour depends on mode | State → variant + `step(s, event): Result` | [details/state.md](details/state.md) |
| a closed set of states whose transitions never fail but emit effects (a log line) | `step(s, event): tuple[next: State, effect: Option[E]]`, and `run` folds it collecting the effects; with a fixed signature that has no `Result`, an unknown input is logged, not raised | [details/state.md](details/state.md) |
| interchangeable step | Strategy → a proc value | [details/strategy.md](details/strategy.md) |
| fixed skeleton, varying steps | Template Method → higher-order `func` | [details/template_method.md](details/template_method.md) |
| new operations over a closed family (no other module adds kinds) | Visitor → variant + `case` | [details/visitor.md](details/visitor.md) |
| new kinds added by other modules (an open family) | a record of procs per value: each kind is a constructor returning the record | [details/visitor.md](details/visitor.md), heading "Open form" |
| keep decisions testable, effects at the edge | Functional core, imperative shell | [details/functional_core.md](details/functional_core.md) |
| history as the source of truth | Event sourcing | [details/event_sourcing.md](details/event_sourcing.md) |
| separate write model and read models | CQRS | [details/cqrs.md](details/cqrs.md) |
| allowed transitions as data | State machine | [details/state_machine.md](details/state_machine.md) |
| a program as a value, many interpreters | Free interpreter | [details/free_interpreter.md](details/free_interpreter.md) |
| one program, meaning chosen by type | Tagless final | [details/tagless_final.md](details/tagless_final.md) |
| inject clock, mail, storage | Dependency record | [details/dependency_record.md](details/dependency_record.md) |
| waits, deadlines and timestamps that must not break when the clock jumps (rather than how to inject the clock: dependency record) | Time as input → wall and monotonic as distinct types, one `Now` read at the edge, `none` for a time not yet come | [details/time_as_input.md](details/time_as_input.md) |
| middleware around handlers | Pipeline | [details/pipeline.md](details/pipeline.md) |
| at-least-once delivery, no double effects | Idempotent command | [details/idempotent_command.md](details/idempotent_command.md) |
| a reader must see the old file or the new one, never half, even across a crash | Atomic publish → temporary name in the same directory, fsync, rename, fsync the directory; a hash as the name when the content can name itself | [details/atomic_publish.md](details/atomic_publish.md) |
| update deep inside immutable data | Lens | [details/lens.md](details/lens.md) |
| parse text into an AST | Parser combinators | [details/parser_combinator.md](details/parser_combinator.md) |
| retry failed calls politely | Retry with backoff | [details/retry_backoff.md](details/retry_backoff.md) |
| independent parties with private state, talking by messages (rather than one shared state: observer, state) | Actor → pure `step` returning state and effect data, persistent mailbox, a host loop | [details/actor.md](details/actor.md) |
| a running party died and something must decide what to restart (rather than repeating one call: retry) | Supervisor → pure `onExit` decision, strategies and a restart limit with time as data | [details/supervisor.md](details/supervisor.md) |
| an actor needs an answer without blocking | Request/reply → correlation id, reply-to, a ledger of pending requests, timeout as a message | [details/request_reply.md](details/request_reply.md) |
| what a caller may do must be limited (rather than swappable: dependency record) | Object capability → sealed value, attenuation, delegation by passing | [details/object_capability.md](details/object_capability.md) |
| a grant must be taken back | Caretaker → forwarder plus revoker, revocation state threaded as data | [details/caretaker.md](details/caretaker.md) |
| a value must pass through parties that must not read or forge it | Sealer/unsealer → a matched pair over a sealed box | [details/sealer_unsealer.md](details/sealer_unsealer.md) |
| a shape many callers use must change without a moment when one of them breaks | Parallel change (expand, migrate, contract) → both shapes written in step, `backfill`, then a `contract` that refuses while a row would lose data | [details/parallel_change.md](details/parallel_change.md) |
| a whole system must be replaced while it keeps serving, and one front door sees every request | Strangler fig → a route table from prefixes to old or new, moved one prefix at a time, with a fallback to the old | [details/strangler_fig.md](details/strangler_fig.md) |
| an implementation must be replaced inside one program over many commits, without a long-lived branch | Branch by abstraction → callers take a record of procs; a stage value (old, shadow, new) picks the implementation | [details/branch_by_abstraction.md](details/branch_by_abstraction.md) |
| a foreign model (a partner's message, a legacy schema) must not shape yours | Anti-corruption layer → a translating `func` per foreign version, built through your smart constructor, refusals as values | [details/anti_corruption_layer.md](details/anti_corruption_layer.md) |
| code that reaches for its dependencies from inside must be changed but cannot yet be tested | Seam → pass the dependency in as a proc, check old against new, pin today's behaviour before refactoring | [details/seam.md](details/seam.md) |
| a specification row lists values that the tests also list, or says two things at once | Executable specification → one sentence per rule in the specification, the values in an example table the test runs, the rule in a type with private fields | [details/executable_specification.md](details/executable_specification.md) |
| a record with a tag and every kind's fields, branched on in `if` chains that end in a default | Replace conditional with polymorphism → one variant per kind, `case` without `else` | [details/replace_conditional_with_polymorphism.md](details/replace_conditional_with_polymorphism.md) |
| one condition mixes several ideas (age, weekday, flag) | Decompose conditional → a named `func` per idea, the decision reads as their combination | [details/decompose_conditional.md](details/decompose_conditional.md) |
| a long routine with comments between its steps | Extract function → one `func` per step, the original becomes their composition | [details/extract_function.md](details/extract_function.md) |
| fields that always travel together with rules between them (amount and currency) | Extract type → a sealed value object with a smart constructor | [details/extract_type.md](details/extract_type.md) |
| a routine with many same-typed arguments in a row | Introduce parameter object → a named record with defaults | [details/introduce_parameter_object.md](details/introduce_parameter_object.md) |
| rules, application service and I/O must depend in one direction only | Layered architecture → domain, service and shell modules; imports point down | [details/layered_architecture.md](details/layered_architecture.md) |
| an interactive program (UI, TUI, game loop) | Model-view-update → one model value, messages, pure `update` and `view` | [details/model_view_update.md](details/model_view_update.md) |
| a service must refuse work it cannot finish in time instead of queueing it | Load shedding → a pure admit decision on queue length, priority and deadline, with a reason | [details/load_shedding.md](details/load_shedding.md) |
| calls to a failing dependency must stop for a while instead of piling up (rather than retrying each call: retry with backoff) | Circuit breaker → closed, open and half-open as a variant; the clock as an argument; a pure transition returning the decision | [details/circuit_breaker.md](details/circuit_breaker.md) |
| one partition's load must not take the capacity of the others (rather than refusing by queue length: load shedding) | Bulkhead → permits per compartment, a pure admit and release over the value | [details/bulkhead.md](details/bulkhead.md) |
| at most N actions per period, with bursts up to a limit | Token bucket → refill computed from the elapsed time passed in, `tryTake` returns the new bucket and the answer | [details/token_bucket.md](details/token_bucket.md) |
| a change spans several services and cannot be one transaction | Saga → steps with compensations, a pure interpreter returning effects as data, compensations in reverse order | [details/saga.md](details/saga.md) |
| a pass over a collection must add or remove elements or change what others refer to (not an in-place update of the element at hand) | Command buffer → `plan` only reads and returns `seq[WorldCmd]` over handles, `applyAll` writes after the loop, a stale handle is a no-op | [details/command_buffer.md](details/command_buffer.md) |
| a state change and the messages it must send must not part (rather than writing then sending: lost on a crash) | Transactional outbox → change and messages as one value, a relay that delivers at least once, an idempotent receiver | [details/transactional_outbox.md](details/transactional_outbox.md) |

## Why the functional form

The point of each translation is that the decision becomes a pure function of values, so its
laws can be property-tested: replaying an event log twice gives the same state; an actor's mailbox is processed in order; an attenuated capability never permits more than its parent; a command followed
by its undo is the identity; a lens obeys get-set, set-get and set-set; the same idempotency key
delivered twice changes nothing; a parser reads back what the printer wrote.

```nim
type
  Light = enum red, green, yellow
  Event = enum timer, emergency

func step(s: Light; e: Event): Light {.raises: [].} =
  case e
  of emergency: red
  of timer:
    case s
    of red: green
    of green: yellow
    of yellow: red

# The whole behaviour is a value-to-value function: test it without mocks.
doAssert step(step(step(red, timer), timer), timer) == red
doAssert step(green, emergency) == red
```

## Pitfalls shared by many patterns

- An object variant gets no automatic `==`; write one when tests compare variants. A plain object,
  `seq` fields included, gets `==` field by field.
- A source field named after a Nim keyword (`type`, `object`, `method`) is renamed in the port (`kind`),
  with the original name in a comment.
- A proc field type must spell its effects (`{.noSideEffect, raises: [].}`) or a `func` cannot call it.
- A record of procs is the escape hatch for open extension; prefer a variant while the set of cases is closed.
