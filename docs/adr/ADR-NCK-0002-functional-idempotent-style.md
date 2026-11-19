# ADR-NCK-0002: Functional, idempotent modern Nim as the house style

**ADR ID**: ADR-NCK-0002
**Status**: accepted
**Date**: 2026-11-19
**Author**: jasagiri (drafted by Claude Opus 5.5)

## Context

The modules, skills and dataset of this repository teach small models how to build algorithms,
data structures and designs in Nim. beautifulnim already teaches idiomatic Nim (naming, effects,
ownership, error handling). What a model copies from this repository is the *shape* of a solution,
so the shape has to be one that stays correct when copied: no hidden state, failures in the type,
laws written down and tested.

## Requirements

- Every module compiles under beautifulnim's `lints/nim.cfg` (copied into `nim.cfg`) and reports
  nothing at `beautifulnim check --min-level:warning`.
- A reader can tell from a signature whether a routine has effects and how it fails.
- An operation that is meant to be idempotent, associative, invertible or order-free says so, and a
  property test checks it.
- The tools that build the catalog and the dataset give byte-identical output for identical input.

## Options

1. **Imperative Nim with `var` parameters and exceptions** (the shape most books use). Familiar,
   fast, but a copied snippet carries mutation and unlisted exceptions into the caller.
2. **Pure functional Nim everywhere, no `var` at all.** Easy to reason about, but some algorithms
   (in-place partition, union-find with path compression, DP tables) become slow or contorted, and
   the model would learn shapes no Nim programmer writes.
3. **Functional at the boundary, local mutation inside.** Public routines are `func` with
   `{.raises: [].}` and return new values; a `var` may live inside a routine when no caller can
   observe it (the routine is still pure from outside).

## Trade-offs

Option 1 teaches what the model already does badly. Option 2 is honest but wrong for Nim, whose
value semantics make local mutation safe and cheap. Option 3 keeps every signature pure and lets
each body be as fast as the algorithm needs; its cost is a rule that has to be judged (is the
mutation really local?), which review and the effect system (`func` = `noSideEffect`) cover.

## Decision

Option 3. The rules:

- **S1 Signatures.** Public routines are `func` and carry `{.raises: [].}`. A routine that cannot
  be `func` (it reads a file, the clock, randomness) is `proc`, says why in its doc comment, and
  lives in a tool or at the edge of a pattern ("functional core, imperative shell"), not in a data
  structure or algorithm module.
- **S2 Failure.** Expected failure is a value: `Option[T]` for "absent", `Result[T, E]`
  (`nimcs/fp/result`) for "failed with a reason". Exceptions are not control flow; a `Defect` is
  reserved for a broken precondition the caller could have checked.
- **S3 Data.** Plain `object`s with value semantics. A closed set of shapes is an object variant
  with an exhaustive `case` (no `else` on an enum). A domain value is a `distinct` type built by a
  smart constructor. `ref` only for sharing structure (persistent data structures) or recursion,
  and then `ref` to an immutable node. No `method`, no inheritance, no `converter`, no global
  mutable state.
- **S4 Persistence.** An "update" returns a new value and leaves the old one valid; persistent
  structures share structure instead of copying.
- **S5 Local mutation.** `let` first. A `var` may exist inside a routine when nothing outside can
  observe it; it is never a `var` parameter of a public routine.
- **S6 Laws.** Each law the concept has (idempotence `f(f(x)) == f(x)`, round trip
  `decode(encode(x)) == x`, associativity and identity of a combine, commutativity, invariants of a
  structure such as "a red node has no red child") is a property test with nim-propcheck, tagged
  with the spec ID that states it.
- **S7 Determinism.** Same input, same output: no iteration over a hash table whose order leaks
  into output, no time or randomness except a fixed seed given as an argument.
- **S8 Toolchain.** Nim 2.4.2, `--mm:orc`; the repository does not choose where executables go
  (`-o:` only for the tools the tests run from `bin/`).

## Not decided here

- Performance targets. Modules are reference implementations; a benchmark is written only where a
  concept is about performance (and then with the measured numbers).

## Rejected alternatives

Options 1 and 2 above.
