---
name: nim-functional-core
description: >-
  Write Nim in the repository's functional, idempotent house style: pure `func` with
  `{.raises: [].}`, failure as `Option` or `Result`, plain value objects and object variants,
  sealed domain values built by smart constructors, local-only mutation, and laws (idempotence,
  associativity, round trips) checked as property tests. Load it before writing or reviewing any
  Nim function, data structure or algorithm for this repository, when asked for "functional",
  "pure", "idempotent", "retry-safe", "monoid", "fold", "Result", "Option" or "parse, don't validate"
  Nim, and whenever a snippet you are about to write takes a `var` parameter, raises an exception
  for an expected failure, or mutates global state.
---

# Functional core in Nim

This skill is the ADR-NCK-0002 rulebook (S1 to S8) written for a model that is about to write Nim.
The shape of a solution is what gets copied, so each rule below is about shape. A routine that
follows them is easy to test, safe to retry and safe to call from anywhere. The idiomatic syntax
(naming, `sink`, `lent`, effects) is taught by the sibling skill `nim-best-practices`; this one is
about how the pieces fit together.

Build with Nim 2.4.2 and `--mm:orc`. Every module compiles with `--styleCheck:error` and the warnings
as errors listed in `nim.cfg`; fix a warning, never switch it off.

## How to use the rules

1. Write the signature first: `func`, argument types, return type, `{.raises: [].}`.
2. Decide how it can fail and put that in the return type (S2).
3. Write the body with `let`; allow one local `var` only when it makes the algorithm clear (S5).
4. Name the laws the routine has and write each as a property test (S6).
5. Run `nim c -r` on the tests, then `beautifulnim check --min-level:warning` on the files.

## S1. Signatures: `func` and `{.raises: [].}`

A public routine is a `func` (the compiler proves it has no side effects) and lists no exceptions.
The reader learns from the signature that it is pure and total. Reading a file, the clock or random
numbers makes a routine a `proc`; keep such procs at the edge and call pure `func`s from them
("functional core, imperative shell").

```nim
func clampPercent(x: int): int {.raises: [].} =
  if x < 0: 0
  elif x > 100: 100
  else: x

doAssert clampPercent(140) == 100
```

Pass a function as `proc(x: T): U {.noSideEffect, raises: [].}`; the compiler then refuses a callback
that prints or may raise. Return values by value, never through a `var` out-parameter.

## S2. Failure is a value

Absence is `Option[T]`. Failure with a reason is `Result[T, E]` from `nimcs/fp/result`. Exceptions are
not control flow, and a `Defect` is only for a broken precondition the caller could have checked.
Never use a sentinel (`-1`, `""`, `nil`) and never hide an error with `discard`, `_ =`, an empty
`except` or a default value that makes the failure vanish.

```nim
import std/options
import nimcs/fp/result

type DivError = enum
  byZero

func safeDivide(a, b: int): Result[int, DivError] {.raises: [].} =
  if b == 0: err(int, byZero) else: ok(a div b, DivError)

func firstEven(xs: openArray[int]): Option[int] {.raises: [].} =
  for x in xs:
    if x mod 2 == 0:
      return some(x)
  none(int)

doAssert safeDivide(7, 0).isErr
doAssert firstEven([1, 3, 4]) == some(4)
```

Chain fallible steps with `flatMap`; the first error stops the chain. Library code that converts a
stdlib exception into an error value (for example `parseInt`) catches that one exception type, names
it, and returns `err`; it does not swallow it. See `details/result.md`, `details/option_ops.md`.

## S3. Data: value objects, variants, distinct types

Model data as plain `object`s. A closed set of shapes is an object variant, and every `case` over it
lists every kind with no `else`. A domain value (a quantity, an identifier) that must obey a rule is a
sealed type: an object with a private field and `{.requiresInit.}`, created only by a smart constructor
that returns `Result`. `distinct` is for units and identifiers that must not be mixed with other
types, but it does not carry a rule: `Quantity(5000)` compiles anywhere and a default `distinct int`
is 0. Use `ref` only to share structure or to recurse, and then only to immutable nodes. Never use
`method`, inheritance, `converter` or a global mutable variable.

```nim
type
  ShapeKind = enum
    circle, rectangle
  Shape = object
    case kind: ShapeKind
    of circle:
      radius: float
    of rectangle:
      width, height: float

func area(s: Shape): float {.raises: [].} =
  case s.kind
  of circle: 3.14159 * s.radius * s.radius
  of rectangle: s.width * s.height

doAssert area(Shape(kind: rectangle, width: 2.0, height: 3.0)) == 6.0
```

Smart constructors are the second half of S3: parse once at the boundary, then every function that
takes the domain type trusts it. Read `.value` only after checking `isOk` and `.error` only after
checking `isErr` (each raises `FieldDefect` on the other case), or use `valueOr`. `nimcs/fp/result`
exports `map` and `flatMap` for `Result`; on a `seq` in the same module, use a loop or `mapIt`
rather than `xs.map(f)`, which can resolve to the `Result` overload. A module whose exported
routines return `Result` writes `export result`, or its callers get "undeclared field" on `isErr`.

A new sealed type, complete (the field has no `*`, so other modules can neither set it nor build a
default value):

```nim
import nimcs/fp/result

type
  PercentError* = enum
    belowZero, aboveHundred
  Percent* {.requiresInit.} = object
    points: int              # private: only `percent` below can set it

func percent*(n: int): Result[Percent, PercentError] {.raises: [].} =
  if n < 0: err(Percent, belowZero)
  elif n > 100: err(Percent, aboveHundred)
  else: ok(Percent(points: n), PercentError)

func points*(p: Percent): int {.raises: [].} = p.points   # read access

doAssert percent(42).isOk and percent(42).value.points == 42
doAssert percent(101).isErr and percent(101).error == aboveHundred
```

```nim
import nimcs/fp/[result, smart_constructor]

let q = parseQuantity(12)
if q.isOk:
  doAssert q.value.value == 12
doAssert parseQuantity(0).isErr
doAssert not compiles(Quantity(n: 5000))     # the field is private: no way to forge one
```

See `details/adt.md`, `details/smart_constructor.md`.

## S4. Persistence: an update returns a new value

An "update" never changes its argument. It returns a new value and the old one stays valid, so history,
undo and sharing are free. Take the argument as `sink` when the routine builds on it; the compiler
moves when the caller is done with the old value and copies otherwise. For big collections use a
persistent structure that shares nodes instead of copying (see the `ds` area).

```nim
import nimcs/fp/[result, immutable_update]

let v1 = initCart().added(Item(sku: "tea", qty: 1, unitCents: 300))
if v1.isOk:
  let v2 = v1.value.added(Item(sku: "milk", qty: 2, unitCents: 150))
  doAssert v1.value.items.len == 1      # the old cart is still valid
  doAssert v2.isOk and v2.value.items.len == 2
```

See `details/immutable_update.md`.

## S5. Local mutation only

Prefer `let`. A `var` may live inside a routine when nothing outside can observe it; the routine is
still pure from outside. A `var` parameter on a public routine is not allowed.

```nim
func sumSquares(xs: openArray[int]): int {.raises: [].} =
  var acc = 0              # local: nobody else can see it
  for x in xs:
    acc += x * x
  acc

doAssert sumSquares([1, 2, 3]) == 14
```

The same local-accumulator body is what a fold is; write the step as a function and let `foldLeft` carry
the loop (`details/fold.md`). Do not mutate a parameter, and do not store mutable state in a module
variable to "remember" something between calls.

## S6. Laws are property tests

A concept with a law states it as a spec row with an ID and tests it with nim-propcheck. Typical laws:
idempotence `f(f(x)) == f(x)`, round trip `decode(encode(x)) == x`, associativity and identity of a
combine, commutativity, and structure invariants. The test name is Given-When-Then and the line above
it names the spec ID.

```nim
import std/unittest
import propcheck
import nimcs/fp/idempotence

# SPEC: FP-IDEMPOTENCE-01
test "FP-IDEMPOTENCE-01 Given any text, when normalizeSpaces is applied twice, then it equals once":
  let outcome = check(stringOf("ab  ", 0, 15), proc(s: string): bool {.raises: [CatchableError].} =
    isIdempotentAt(normalizeSpaces, s))
  checkpoint describe(outcome)
  check outcome.passed
```

The propcheck API (`import propcheck`; the sibling package nim-propcheck, on the path through
`nim.cfg`): `check(gen, property): CheckResult[T]` where `property` is
`proc(x: T): bool {.raises: [CatchableError].}`, the result has `.passed` and `describe(result)` says
why it failed; generators `intIn(lo, hi)`, `pick(values)`, `seqOf(gen, minLen, maxLen)`,
`stringOf(alphabet, minLen, maxLen)`, `pair(genA, genB)` and `gen.map(f)` with `f: proc(a: A): B {.raises: [].}`. In a
`std/unittest` file, `check(gen, property)` with two arguments is propcheck's; its result must be
used, and `check outcome.passed` is unittest's assertion. Build generators inside the test body
(they raise `ValueError` when their arguments are wrong). A passing run with a fixed seed is reproducible; a failure prints a
shrunk counterexample. Idempotence (`details/idempotence.md`) and the monoid laws
(`details/monoid.md`) are the two families you will use most.

A value with several fields is generated as a `pair` (or a `seqOf` for a list) turned into the
record with `map`. A type sealed by a smart constructor cannot be generated directly: generate the
raw input, pass it through the constructor, and treat `Err` as "nothing to check" (return `true`).
The round trip is then printing and parsing again. `isErr` and `.value` come from
`nimcs/fp/result`, so import it next to the constructor's module:

```nim
import std/unittest
import propcheck
import nimcs/fp/[result, smart_constructor]

type RawOrder = object      # the unchecked input, one field per form field
  name: string
  qty: int

test "Given any raw order, when it parses, then printing and parsing again gives the same order":
  let raws = pair(stringOf("ab_1 ", 0, 12), intIn(-5, 1200)).map(
    proc(p: (string, int)): RawOrder {.raises: [].} = RawOrder(name: p[0], qty: p[1]))
  let outcome = check(raws, proc(r: RawOrder): bool {.raises: [CatchableError].} =
    let who = parseUsername(r.name)
    let qty = parseQuantity(r.qty)
    if who.isErr or qty.isErr: return true    # rejected input: nothing to round-trip
    let again = parseQuantityText($qty.value)
    parseUsername($who.value) == who and again.isOk and again.value == qty.value)
  checkpoint describe(outcome)
  check outcome.passed
```

## S7. Determinism

Same input, same output. Do not let the iteration order of a hash table reach the output: sort, or
use a sequence. No clock and no randomness inside a `func`; if randomness is needed, take a seed as an
argument and derive from it.

```nim
import std/[algorithm, tables]

func sortedKeys(t: Table[string, int]): seq[string] {.raises: [].} =
  for k in t.keys:
    result.add k
  result.sort()

var t = initTable[string, int]()
t["b"] = 1
t["a"] = 2
doAssert sortedKeys(t) == @["a", "b"]
```

## S8. Toolchain

Nim 2.4.2, `--mm:orc`, and the compiler settings of the repository's `nim.cfg`. Executables are
placed where the shared `config.nims` puts them; do not hard-code an output path.

## Smaller rules that the above implies

- Argument order: the structure first (`q.push(x)`), so method-call syntax reads as a pipeline.
- Prefer `Fn`-style pure callbacks and small named functions over inline closures with captured state.
- `Option` for absent, `Result` for failed; do not return `Result[T, string]` when an enum says more.
- Make an illegal state unrepresentable (enum, variant, sealed object with a smart constructor) before adding a check; `distinct` alone does not do it.
- Write the contract in the doc comment when the type cannot say it (sorted input, bounds, units).
- Every claim in a comment or doc is implemented and tested; otherwise write `TODO:` or `Future:`.

## Idempotence and monoids in one paragraph

If an operation may be repeated (a retry, a replay, a merge of overlapping data), make it idempotent
or guard it with an idempotency key stored in the state, and test `f(f(x)) == f(x)`. If values are
combined, find the `combine` and the `empty` and test identity and associativity; then a fold needs no
direction, can be split into halves and merged, and an empty input has a defined answer.

## Checking your work

Run, from the repository root:

```sh
nim c -r --hints:off tests/test_fp_<concept>.nim
../beautifulnim/beautifulnim check --min-level:warning src/nimcs/fp/*.nim tests/test_fp_*.nim
```

Both must exit with 0. Each `nim` block in this skill and in `details/` compiles on its own.

## The details pages

| Concept | Page | Module | Spec IDs |
|---|---|---|---|
| Result railway | `details/result.md` | `src/nimcs/fp/result.nim` | FP-RESULT-01 to 06 |
| Option operations | `details/option_ops.md` | `src/nimcs/fp/option_ops.nim` | FP-OPTIONOPS-01 to 08 |
| Fold, scan, unfold | `details/fold.md` | `src/nimcs/fp/fold.nim` | FP-FOLD-01 to 07 |
| Immutable update | `details/immutable_update.md` | `src/nimcs/fp/immutable_update.nim` | FP-IMMUTABLEUPDATE-01 to 07 |
| Composition and pipelines | `details/compose.md` | `src/nimcs/fp/compose.nim` | FP-COMPOSE-01 to 06 |
| Lazy streams | `details/lazy_stream.md` | `src/nimcs/fp/lazy_stream.nim` | FP-LAZYSTREAM-01 to 08 |
| Algebraic data types | `details/adt.md` | `src/nimcs/fp/adt.nim` | FP-ADT-01 to 07 |
| Smart constructors | `details/smart_constructor.md` | `src/nimcs/fp/smart_constructor.nim` | FP-SMARTCONSTRUCTOR-01 to 08 |
| Idempotence | `details/idempotence.md` | `src/nimcs/fp/idempotence.nim` | FP-IDEMPOTENCE-01 to 09 |
| Monoid | `details/monoid.md` | `src/nimcs/fp/monoid.nim` | FP-MONOID-01 to 07 |

Read the details page of a concept before writing code of that kind; each lists use and avoid cases,
the laws with their spec IDs, complexity, and the wrong shape to avoid.
