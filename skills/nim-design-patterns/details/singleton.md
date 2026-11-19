# Singleton

## Intent
Guarantee exactly one instance of a type and give it a global access point. **Avoid this pattern in
Nim.** Both halves cause damage: the global is hidden state that makes every caller impure and every
test order-dependent, and "exactly one" is rarely a real requirement. There are two honest
replacements, depending on what the thing is.

## Use when / avoid when
- Fixed data (defaults, tables, limits): a `const` (or module-level `let`) of an immutable value.
  Derive variants with a `withX` func; the constant cannot change.
- A capability (clock, random source, logger, store): pass it as a value, usually a record of procs,
  to the routines that need it. Production passes the real one, tests pass a fixed one.
- Real shared mutable state (a connection pool, a cache): keep it at the edge of the program (the
  imperative shell), owned by one proc such as `main`, and hand values derived from it to the pure core.
- Avoid a module-level `var`, a `{.threadvar.}` used as a lazy global, and `getInstance()` procs.
  They are global mutable state, forbidden by ADR-NCK-0002 S3.

## Nim shape
`DefaultSettings` is the constant; `Clock` is the injected capability. `stamp` depends on its
arguments and on nothing else, so it is a `func`.

Module: `src/nimcs/patterns/singleton.nim`.

```nim
import nimcs/patterns/singleton

let tuned = DefaultSettings.withRetries(5)
doAssert tuned.retries == 5 and DefaultSettings.retries == 3

let noon = fixedClock(43200)
doAssert stamp(noon, "started") == "43200: started"
doAssert stamp(noon, "started") == stamp(noon, "started")   # deterministic

# Two "instances" side by side: a global could not allow this.
doAssert stamp(fixedClock(1), "x") != stamp(fixedClock(2), "x")
```

## Laws and invariants
- `DefaultSettings` is a constant: deriving a changed copy never alters it (GOF-SINGLETON-01).
- `stamp` with a fixed clock is deterministic and contains the clock's time and the message
  (GOF-SINGLETON-02).
- Clocks coexist independently; stamps differ exactly when the times differ (GOF-SINGLETON-03).

## Complexity
Constants are computed at compile time and cost nothing at run time. Passing a `Clock` costs one
extra argument and an indirect call.

## Pitfalls
The lazy global.

```nim bad
var instance: ref int

proc counter(): ref int =
  if instance.isNil:
    instance = new(int)
  instance
```

Own the state in `main` (or not at all) and pass the value:

```nim
func next(n: int): int = n + 1

proc main() =
  var count = 0          # owned here, local
  count = next(count)
  count = next(count)
  doAssert count == 2

main()
```

## Related
- `facade.md` (a small module-level API without global state), `proxy.md` (a record of procs standing in for a resource).

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `25f90d554113e6d5` Scala & Design Patterns: Exploring Language Expressivity
- `0789f21330e7f72a` Source Making Design Patterns and UML
- `690b10bb5f31ac02` The Catalog of Design Patterns
