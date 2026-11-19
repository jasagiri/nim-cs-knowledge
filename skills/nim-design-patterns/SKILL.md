---
name: nim-design-patterns
description: >-
  Apply, translate or review a design pattern in Nim — the 23 GoF patterns and functional
  architecture patterns (functional core / imperative shell, event sourcing, CQRS, state machines,
  free and tagless-final interpreters, dependency records, middleware pipelines, idempotent
  commands, lenses, parser combinators, retry with backoff). Use whenever Nim code reaches for
  classes, inheritance, `method`, callbacks, global singletons or mutable shared state, when a
  design is being ported from Java/C#/C++/Python, or when a request names a pattern. Shows what
  each pattern becomes in functional Nim, and which ones disappear.
---

# Design patterns in functional Nim

Most object-oriented patterns exist to work around missing language features: first-class
functions, sum types, value semantics, generics. Nim has all four, so a pattern either becomes a
smaller, more direct shape or disappears. Every pattern here has a tested module
`src/nimcs/patterns/<name>.nim` and a details page; read the page before using the pattern.

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
| react to happenings | Observer → events folded by reducers | [details/observer.md](details/observer.md) |
| behaviour depends on mode | State → variant + `step(s, event): Result` | [details/state.md](details/state.md) |
| interchangeable step | Strategy → a proc value | [details/strategy.md](details/strategy.md) |
| fixed skeleton, varying steps | Template Method → higher-order `func` | [details/template_method.md](details/template_method.md) |
| new operations over a closed family | Visitor → variant + `case` | [details/visitor.md](details/visitor.md) |
| keep decisions testable, effects at the edge | Functional core, imperative shell | [details/functional_core.md](details/functional_core.md) |
| history as the source of truth | Event sourcing | [details/event_sourcing.md](details/event_sourcing.md) |
| separate write model and read models | CQRS | [details/cqrs.md](details/cqrs.md) |
| allowed transitions as data | State machine | [details/state_machine.md](details/state_machine.md) |
| a program as a value, many interpreters | Free interpreter | [details/free_interpreter.md](details/free_interpreter.md) |
| one program, meaning chosen by type | Tagless final | [details/tagless_final.md](details/tagless_final.md) |
| inject clock, mail, storage | Dependency record | [details/dependency_record.md](details/dependency_record.md) |
| middleware around handlers | Pipeline | [details/pipeline.md](details/pipeline.md) |
| at-least-once delivery, no double effects | Idempotent command | [details/idempotent_command.md](details/idempotent_command.md) |
| update deep inside immutable data | Lens | [details/lens.md](details/lens.md) |
| parse text into an AST | Parser combinators | [details/parser_combinator.md](details/parser_combinator.md) |
| retry failed calls politely | Retry with backoff | [details/retry_backoff.md](details/retry_backoff.md) |

## Why the functional form

The point of each translation is that the decision becomes a pure function of values, so its
laws can be property-tested: replaying an event log twice gives the same state; a command followed
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

- An object variant gets no automatic `==`; write one when tests compare variants.
- A proc field type must spell its effects (`{.noSideEffect, raises: [].}`) or a `func` cannot call it.
- A record of procs is the escape hatch for open extension; prefer a variant while the set of cases is closed.
