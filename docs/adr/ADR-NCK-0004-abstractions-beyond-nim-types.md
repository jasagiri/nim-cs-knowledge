# ADR-NCK-0004: Abstractions that Nim's types cannot express

**ADR ID**: ADR-NCK-0004
**Status**: accepted
**Date**: 2026-11-21
**Author**: jasagiri (drafted by Claude Opus 5.5)

## Context

The source catalog names several functional-programming topics whose usual form needs a type
system feature that Nim 2 does not have: higher-kinded types (a functor or monad over any type
constructor), GADTs (a sum type whose constructors fix the type index), arrows and comonads in
general form, and effect systems beyond `raises` and `tags`. Iteratees and FRP are usually shown with
the same features but do not need them.

A page that shows Haskell-style code would not compile; a page that pretends Nim has the feature
would teach a wrong model. ADR-NCK-0001 requires every code block to compile alone, and
ADR-NCK-0002 requires public routines to be `func` with `{.raises: [].}`.

## Requirements

- Every page's code compiles with the current Nim 2 and is tested.
- A reader learns what the abstraction gives, and how much of it Nim gives today.
- The cost of the missing feature is visible, so it can be argued upstream with numbers.

## Options

- A. Leave these topics out of the knowledge base.
- B. Teach the per-type form: write `map`, `flatMap`, `ap`, `map2` for each container (`Option`,
  `Result`, `seq`, `ConsList`, `Stream`), state the laws once, and test each instance against them.
  Explain in the page what the general form would be and why Nim cannot write it.
- C. Emulate the feature with macros or concepts (for example a `Functor` concept with a
  `map` requirement), accepting code that is harder to read and checks less.
- D. Write the pages against nimony's plugins, which can compute types.

## Trade-offs

- A loses topics that several sources treat as core; readers then meet the names without a Nim
  answer.
- B compiles and is checked today. It repeats each operation per container; the laws are what is
  shared, and the tests enforce them per instance.
- C hides the repetition but a concept cannot express "for every `F`", so the abstraction is partial
  and the error messages get worse.
- D is not available: measured on nimony master 1858291129ae with small probe programs (kept
  outside this repository), a `Functor` concept over a type constructor is rejected
  (`Box[int64] does not match constraint Functor`), a generic `fmap[F, A, B](x: F[A]; ...)` is
  rejected (`cannot attempt to instantiate a non-type`), and a single GADT-style sum type accepts
  `IntLit(v: 5)` as an `Expr[bool]`. nimony is also not the Nim this repository targets.

## Decision

B. The functor/monad page teaches the per-type instances and the laws; its "Nim shape" section
names the general form, says which Nim feature is missing (higher-kinded parameters; GADTs, arrows
and comonads are not language features either), and shows the per-type workaround and a generic
checked at instantiation. The type-class page links to it for the same limit. GADTs, arrows,
comonads, iteratees and FRP have no page of their own.

The functor/monad page carries a `Future:` line naming what nimony lacks for the general form (see
`## 外への提案`); when nimony has it, the line points to the nimony form. The page is not rewritten
until this repository targets nimony.

## Not decided here

- Whether to add pages for GADTs, arrows, comonads, iteratees or FRP. The nimony probes show arrows
  and comonads on concrete types, iteratees and FRP compile as plain libraries, so they need no new
  type feature.
- Whether this repository moves to nimony.

## Rejected alternatives

- C (concept emulation): it compiles for one container at a time only, so it adds indirection
  without the generality it suggests.

## 外への提案

- Upstream: nimony (nim-lang/nimony). Seed: a generic routine cannot take a type constructor as a
  parameter, and a type plugin's deferred result is not re-expanded after its type variables are
  bound, so a functor/monad has to be written once per container.
  - Workaround cost [測った 2026-11-21, this repository]: 10 per-container definitions of 4
    operations (`map` in `fp/result.nim`, `ds/cons_list.nim`, `fp/lazy_stream.nim`; `flatMap` in
    `fp/result.nim`, `fp/functor_monad.nim`; `ap` ×3 and `map2` ×2 in `fp/functor_monad.nim`),
    each with its own law tests. A type-constructor parameter would make it one definition per
    operation plus one instance per container.
  - Measured blockers [測った, nimony 1858291129ae, probe programs outside this repository]:
    `F[A]` with a type variable `F` is rejected at the declaration; a type plugin `Apply(F, A)`
    deferred while `F` is unbound is compared by shape after `F` is bound
    (`expected: (pluginCall Apply F A) but got: Option[int64]`).
- Upstream: nimony. Seed: a sum type cannot fix its type index per constructor (GADT), so an
  expression tree with a typed `eval` needs the phantom-type workaround with an unchecked body.
  - Workaround cost [測った]: the phantom form checks construction only; a probe
    shows a single sum type accepting `IntLit` as `Expr[bool]`.
