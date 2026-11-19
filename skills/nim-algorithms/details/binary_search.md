# Binary search

## Intent

Halve the candidate range by asking one yes/no question per step. The general form finds where a monotone predicate flips from false to true; lower and upper bound on sorted data are that form with the question "is this element not before / after x".

## Use when / avoid when

- Use when: the data is sorted (or the answer space is monotone: the least size that fits, the first failing build).
- Use `lowerBound`/`upperBound` for insertion points and ranges of equal elements; `binarySearch` for membership with the index.
- Avoid when: the data is unsorted and queried once: a linear scan is cheaper than sorting first.
- Avoid when: you need key lookup on changing data; use a map from `nimcs/ds`.

## Nim shape

`src/nimcs/algo/binary_search.nim`: `firstTrue(lo, hi, pred)` over an integer range, `partitionPoint(xs, pred)` over a sequence, `lowerBound`, `upperBound` and `binarySearch` with an optional comparator. All are `func`s; "not found" is `Option`. The midpoint is `low + (high - low) div 2`, or `floorDiv(low + high, 2)` when the range crosses zero (where `high - low` could overflow; the sum of a negative and a non-negative `int` cannot), so any bounds in the `int` range work. The range is half-open, `[lo, hi)`, so `hi` itself is never tested: to include `high(int)`, search `[lo, high(int))` and test `high(int)` separately.

```nim
import std/options
import nimcs/algo/binary_search

let xs = @[1, 3, 3, 3, 8]
assert lowerBound(xs, 3) == 1
assert upperBound(xs, 3) == 4
assert binarySearch(xs, 8) == some(4)
assert binarySearch(xs, 5).isNone

# Answer search: the least n with n * n >= 50.
assert firstTrue(0, 100, proc(n: int): bool {.noSideEffect, raises: [].} = n * n >= 50) == 8
```

## Laws and invariants

- `lowerBound(xs, x)`: everything before it is less than `x`, nothing from it on is (SEARCH-LOWER-01).
- `upperBound(xs, x)`: everything before it is at most `x`, everything from it on is greater (SEARCH-UPPER-01).
- `upperBound - lowerBound` is the number of copies of `x` (SEARCH-RANGE-01).
- `binarySearch` returns the first index of `x` exactly when it is present (SEARCH-FIND-01).
- `partitionPoint(xs, pred)` is the first index where a monotone `pred` holds (SEARCH-PARTITION-01).
- `firstTrue(lo, hi, pred)` is the least index in the range satisfying a monotone `pred`, or `hi` (SEARCH-FIRST-01).

## Complexity

- Time: O(log n) predicate or comparison calls. Space: O(1).

## Pitfalls

Two classic mistakes: computing the midpoint as `(low + high) div 2` (overflows for huge ranges) and a loop that never shrinks the range.

```nim bad
while low < high:
  let mid = (low + high) div 2
  if pred(mid): high = mid
  else: low = mid        # must be mid + 1, otherwise low == mid forever when high == low + 1
```

The fix is `low = mid + 1` with the half-open range `[low, high)`, and `low + (high - low) div 2` for the midpoint. Also: importing `std/algorithm` brings its own `lowerBound`, `upperBound` and `binarySearch`; write `import std/algorithm except lowerBound, upperBound, binarySearch` when you need both.

## Related

- `insertion_sort.nim` and the other sorts (they produce the sorted input), `graph.nim` (searching answer spaces such as shortest path limits).

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `29ca95172575b79a` Algorithms and Data Structures
- `61811291625a13a9` Algorithms for Competitive Programming
- `63ad3e14455a34af` Competitive Programmer's Handbook
- `464f1aa168823232` Computer Science I
- `c6a234b79d2a7c88` Computer Science II
- `5ea7cdc2c5670fd7` Data Structures and Algorithms
- `254fe28ac0bfd53e` Last Moment DSA Sheet(79) – Ace Interviews
- `04a7132319218b7b` Matters Computational: Ideas, Algorithms, Source Code
