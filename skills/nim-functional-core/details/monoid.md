# Monoid

## Intent
A monoid is a way to combine two values (`combine`) together with a value that changes nothing (`empty`). Two laws make it one: identity (`combine(empty, x) == x == combine(x, empty)`) and associativity (`combine(combine(a, b), c) == combine(a, combine(b, c))`). Associativity lets a fold group its work any way, such as splitting a list across threads and combining the halves, and identity gives an empty input a natural answer.

## Use when / avoid when
- Use for aggregates: totals, maxima, concatenation, merging records or tables, collecting statistics.
- Use `foldMap` to map and combine in one pass.
- Avoid when there is no neutral element (the average, for example, is not a monoid; keep a sum and a count, which is).
- Avoid assuming commutativity: string concatenation is associative but order matters.

## Nim shape
`src/nimcs/fp/monoid.nim`: `Monoid[T]` is a record of `empty` and `combine`; constructors build the usual ones.

```nim
import std/tables
import nimcs/fp/monoid

let total = sumMonoid().mconcat([3, 4, 5])
let longest = maxMonoid().foldMap(["a", "abc", "ab"],
  proc(s: string): int {.noSideEffect, raises: [].} = s.len)
doAssert total == 12
doAssert longest == 3

let counts = mapMonoid[string, int](sumMonoid())
var a = initTable[string, int]()
a["x"] = 1
var b = initTable[string, int]()
b["x"] = 2
b["y"] = 5
let merged = counts.combine(a, b)
doAssert merged["x"] == 3 and merged["y"] == 5
```

The laws are properties of the values you put in, not of the type: the test suite checks them with generated inputs for each constructor.

## Laws and invariants
- Sum, product, max and min on `int` satisfy identity and associativity as long as nothing overflows (FP-MONOID-01).
- String and sequence concatenation satisfy both laws (FP-MONOID-02).
- `mapMonoid(m)` is a monoid when `m` is (FP-MONOID-03).
- `mconcat` of nothing is `empty`; `mconcat(a & b) == combine(mconcat(a), mconcat(b))` (FP-MONOID-04).
- `foldMap(xs, f) == mconcat(xs.map(f))` (FP-MONOID-05).
- String concatenation is not commutative (FP-MONOID-06); merging with a sum is (FP-MONOID-07).

## Complexity
`mconcat` and `foldMap` are O(n) combines and O(1) extra space. Merging two tables is O(size of the second) combines. A `combine` that copies (`seq` concatenation) makes a left fold O(n^2) in total length.

## Pitfalls
The identity of `maxMonoid` is `low(int)`, so the maximum of nothing is not a real value; do not treat it as one. Integer `sum` overflow raises in Nim, so it is not a monoid on all of `int`.

```nim bad
# Not associative: (a - b) - c != a - (b - c), so it cannot be folded in halves.
let minus = Monoid[int](empty: 0, combine: proc(a, b: int): int = a - b)
```

```nim
import nimcs/fp/monoid

let m = maxMonoid()
let xs = newSeq[int]()
if xs.len == 0:
  echo "no values"                 # decide about the empty case yourself
else:
  echo m.mconcat(xs)
```

## Related
`fold.md`, `option_ops.md` (`orElse`), `compose.md` (functions under composition), `idempotence.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `14e1135a7e563bfa` CS240h: Functional Systems in Haskell
- `04bc6d730024731d` Haskell Notes for Professionals
- `90944eadae97da9a` Learning Scalaz
