# Result railway

## Intent
A routine that can fail for a reason returns `Result[T, E]`: either `ok` with a value or `err` with the reason. Steps are chained with `flatMap`, so the first failure stops the chain and its reason is what the caller sees, with no exception and no sentinel value. The signature tells the caller that failure is possible and what kind.

## Use when / avoid when
- Use when failure is expected and the caller must decide what to do (parsing, validation, lookup that needs a reason).
- Use when several fallible steps run in sequence and the first failure should win.
- Avoid for plain absence with no reason: use `Option[T]` (see `option_ops.md`).
- Avoid for broken preconditions the caller could have checked: that is a `Defect`, not an error value.
- In an application that already depends on the `results` package, keep using that; this module only resembles it (`ok` and `err` take a type argument, and `.value` on an error raises), so do not mix the two.

## Nim shape
`src/nimcs/fp/result.nim` defines `Result[T, E]` as an object variant. Build values with `ok(value, ErrorType)` and `err(ValueType, reason)`; the type argument is needed because Nim cannot infer the other half.

```nim
import nimcs/fp/result

type StepError = enum
  notEven, negative

func halve(x: int): Result[int, StepError] {.raises: [].} =
  if x mod 2 != 0: err(int, notEven) else: ok(x div 2, StepError)

func nonNegative(x: int): Result[int, StepError] {.raises: [].} =
  if x < 0: err(int, negative) else: ok(x, StepError)

let a = ok(8, StepError).flatMap(halve).flatMap(nonNegative)
let b = ok(7, StepError).flatMap(halve).flatMap(nonNegative)
doAssert a.isOk and a.value == 4
doAssert b.isErr and b.error == notEven
```

`map` changes the value, `mapErr` changes the reason, `valueOr` leaves the railway with a default.

## Laws and invariants
- `r.map(identity) == r` and `r.map(f).map(g) == r.map(g after f)` (FP-RESULT-01).
- The first error stops the chain and is the one reported (FP-RESULT-02).
- `ok(x).flatMap(f) == f(x)`, `r.flatMap(ok) == r`, and `flatMap` is associative (FP-RESULT-03).
- `mapErr` leaves an `ok` untouched and never touches the value side (FP-RESULT-04).
- `valueOr` returns the value of an `ok` and the fallback otherwise (FP-RESULT-05).
- Equality compares the case, then the value or the error (FP-RESULT-06).

## Complexity
Every operation is O(1) apart from the cost of the callback. A `Result` is stored inline; no allocation happens for the railway itself.

## Pitfalls
Reading `.value` without checking `isOk` raises a `FieldDefect`. Handle both cases, or leave the railway with `valueOr`.

```nim bad
let r = halve(7)
echo r.value          # r is an error: FieldDefect at run time
```

```nim
import nimcs/fp/result

func parsePositive(x: int): Result[int, string] {.raises: [].} =
  if x > 0: ok(x, string) else: err(int, "not positive")

let r = parsePositive(-3)
if r.isOk:
  echo "got ", r.value
else:
  echo "failed: ", r.error
```

Another trap: using a `Result` for a plain miss. `find` returning `err("not found")` carries no information; return `Option`.

## Related
`option_ops.md`, `smart_constructor.md`, `adt.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `04c90d5ac6a2d0db` Real World OCaml
