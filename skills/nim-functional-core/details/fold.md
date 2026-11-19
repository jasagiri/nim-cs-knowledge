# Fold

## Intent
A fold reduces a sequence to one value by feeding each element and the accumulator so far to a step function. Sum, count, maximum, reverse, map and filter are all folds that differ only in the step and the starting value. Writing the step as a pure function makes the loop trivial to reason about; `scan` keeps every intermediate value and `unfold` goes the other way, from a seed to a sequence.

## Use when / avoid when
- Use when a result is built by visiting every element once, in order.
- Use `scan` when the running values matter (prefix sums, balances over time).
- Use `unfold` to generate a bounded sequence from a state (countdown, Collatz steps).
- Avoid a fold when the loop needs early exit on a condition: write a `for` with `return`, or `lazy_stream.md` for lazy pipelines.
- Avoid when a standard routine says it better (`sum`, `max`, `sorted`).

## Nim shape

Module: `src/nimcs/fp/fold.nim`.

`foldLeft(xs, init, f)` visits left to right with `f(acc, x)`; `foldRight(xs, init, f)` visits right to left with `f(x, acc)`. The accumulator is a local `var`; the callers see a pure function.

```nim
import nimcs/fp/fold

func add(acc, x: int): int {.raises: [].} = acc + x
func count(acc, x: int): int {.raises: [].} = acc + 1
func prepend(acc: seq[int]; x: int): seq[int] {.raises: [].} = @[x] & acc

let xs = @[3, 1, 4]
doAssert xs.foldLeft(0, add) == 8
doAssert xs.foldLeft(0, count) == 3
doAssert xs.foldLeft(newSeq[int](), prepend) == @[4, 1, 3]
doAssert xs.scan(0, add) == @[0, 3, 4, 8]
```

The names `foldLeft` and `foldRight` differ from `sequtils.foldl` and `foldr` so both can be imported together.

Any iterator can be folded without building a `seq` by writing the loop yourself: `var acc = init; for x in it: acc = f(acc, x)`; that is exactly the body of `foldLeft`.

## Laws and invariants
- An empty input gives `init`; with `+` from 0 it is the sum (FP-FOLD-01).
- `foldLeft(a & b, i, f) == foldLeft(b, foldLeft(a, i, f), f)` (FP-FOLD-02).
- `foldRight` with cons and `foldLeft` with snoc rebuild the input (FP-FOLD-03).
- `foldLeft` and `foldRight` agree for an associative commutative step; they differ for subtraction (FP-FOLD-04).
- `scan` has `len + 1` elements, starts at `init`, ends at the `foldLeft` result (FP-FOLD-05).
- `unfold` stops at `none` and never yields more than `limit` elements (FP-FOLD-06).
- Length, map, filter and reverse are folds (FP-FOLD-07).

## Complexity
`foldLeft`, `foldRight` and `scan`: O(n) steps, O(1) extra space for the fold (`scan`: O(n) for the result). A step that grows the accumulator (appending to a `seq` by `&`) makes the whole fold O(n^2); keep the accumulator constant-size or use a local `add` loop.

## Pitfalls
`foldLeft` and `foldRight` give different results when the step is not associative and commutative; picking the wrong direction for subtraction or string building is the usual bug.

```nim bad
# Intends "a - b - c" but foldRight computes "a - (b - c)".
let r = foldRight([10, 3, 2], 0, proc(x, acc: int): int = x - acc)   # 9, not 5
```

```nim
import nimcs/fp/fold

func minus(acc, x: int): int {.raises: [].} = acc - x

doAssert [10, 3, 2].foldLeft(0, minus) == -15      # ((0 - 10) - 3) - 2
doAssert [3, 2].foldLeft(10, minus) == 5           # 10 - 3 - 2
```

Another trap: `unfold` with a step that never returns `none` relies on `limit`; always pass a limit you can afford.

## Related
`monoid.md` (a fold with a monoid needs no direction choice), `lazy_stream.md`, `compose.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `14e1135a7e563bfa` CS240h: Functional Systems in Haskell
- `04bc6d730024731d` Haskell Notes for Professionals
- `90944eadae97da9a` Learning Scalaz
- `0a6f20dc60d4d0f3` The Haskell School of Music - From Signals to Symphonies
- `731b2d900bf6d003` Write Yourself a Scheme in 48 Hours
