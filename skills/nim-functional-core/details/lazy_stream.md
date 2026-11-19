# Lazy streams

## Intent
A lazy stream computes an element only when it is asked for. `map`, `filter`, `take` and `takeWhile` build a new stream without doing any work and without allocating an intermediate sequence; `toSeq(limit)` finally pulls the elements through the whole pipeline once. Because a stream is an immutable value, it can be walked again with the same result, and infinite streams are safe as long as something cuts them.

## Use when / avoid when
- Use for "the first k things that satisfy a property" over an unbounded or very large source.
- Use to keep a multi-stage pipeline from allocating a sequence per stage.
- Avoid when the data is small: an eager `seq` pipeline is simpler and faster.
- Avoid a `filter` on an infinite stream that never matches: pulling it never returns. Cut with `takeWhile` first when you can.
- For a one-shot walk inside one routine, Nim's own `iterator`s are lighter than a stream value.

## Nim shape
`src/nimcs/fp/lazy_stream.nim`: `Stream[T]` holds one pure function that returns "done" or "element and rest".

```nim
import nimcs/fp/lazy_stream

func next(x: int): int {.raises: [].} = x + 1
func isEven(x: int): bool {.raises: [].} = x mod 2 == 0
func square(x: int): int {.raises: [].} = x * x

let naturals = iterate(1, next)
let firstFour = naturals.filter(isEven).map(square).take(4)
doAssert firstFour.toSeq(100) == @[4, 16, 36, 64]
doAssert firstFour.toSeq(100) == @[4, 16, 36, 64]     # walked twice: same result
```

Nothing is computed until `toSeq`; `iterate` applies its step only when the next element is pulled, so a step that would fail beyond the needed prefix never runs. The required `limit` of `toSeq` is a safety net, not part of the pipeline's meaning.

## Laws and invariants
- `fromSeq(xs).toSeq(n)` is the first `n` elements of `xs` (FP-LAZYSTREAM-01).
- Stream `map` and `filter` equal the eager versions (FP-LAZYSTREAM-02).
- `take(n)` of an infinite stream has exactly `n` elements (FP-LAZYSTREAM-03).
- `iterate` does not run its step for an element that is not pulled: `iterate(high(int) - 2, succ).take(3)` does not overflow (FP-LAZYSTREAM-04).
- A `fromSeq` stream of a long sequence comes back whole and in order (FP-LAZYSTREAM-08).
- Chained `filter`, `map`, `takeWhile` on an infinite stream terminate once cut (FP-LAZYSTREAM-04).
- A stream can be walked twice with the same result (FP-LAZYSTREAM-05).
- `take(n).take(m) == take(min(n, m))` (FP-LAZYSTREAM-06).
- `toSeq(limit)` never returns more than `limit` elements (FP-LAZYSTREAM-07).

## Complexity
Building a stage is O(1). Pulling one element through k stages costs O(k) plus the cost of skipped elements in `filter`. `fromSeq` copies the input once and its stages then share that block (O(1) per step). Each pull allocates a small closure; the memory in use is proportional to the pipeline depth, not to the number of elements walked. Walking the same stream twice repeats the work (no caching).

## Pitfalls
Building the whole sequence "to be lazy later" defeats the point and never ends on an infinite source.

```nim bad
let all = toSeq(1 .. 1_000_000_000)        # allocates first, filters later
echo all.filterIt(it mod 7 == 0)[0 ..< 3]
```

```nim
import nimcs/fp/lazy_stream

func next(x: int): int {.raises: [].} = x + 1
func divisibleBySeven(x: int): bool {.raises: [].} = x mod 7 == 0

let firstThree = iterate(1, next).filter(divisibleBySeven).take(3).toSeq(10)
doAssert firstThree == @[7, 14, 21]
```

A second trap: expecting a stream to remember its elements. It recomputes on each walk; collect with `toSeq` once if the work is expensive.

## Related
`fold.md` (`unfold` is the eager, bounded dual), `compose.md` (map fusion), `option_ops.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `5f760d582444d1a5` Clojure Distilled Beginner Guide
- `7fd69b31060d80f1` ML for the Working Programmer, 2nd Edition
- `9ef987c93e3e3529` Programming in Standard ML, DRAFT
- `e443a6b88b011f39` Purely Functional Data Structures
- `1eb0b9c8c52f2942` Scala By Example
- `4983fd2e157f75bc` Scala Tutorial
- `5b1535e53ceaa7c4` SICP Distilled - An idiosyncratic tour of SICP in Clojure
- `ad1dce2b03a88d89` The Scheme Programming Language: Edition 3
