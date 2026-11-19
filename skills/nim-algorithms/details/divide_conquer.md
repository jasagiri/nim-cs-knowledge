# Divide and conquer, and the master theorem

## Intent
Split a problem into smaller instances of itself, solve them, and combine the answers. The cost of such an algorithm obeys a recurrence
T(n) = a T(n/b) + f(n), and the master theorem reads its order of growth off by comparing the work at the root, f(n), with the work at the leaves.

## Use when / avoid when
- Use it when the halves are independent and combining them is cheap: sorting, selection, maximum subarray, closest pair.
- Use the linear scan (`maxSubarrayKadane`) in practice for the maximum subarray; the divide-and-conquer form is the one that generalises to range queries.
- Avoid it when sub-problems overlap: use `memoization.md` instead, otherwise the same work is repeated exponentially often.

## Nim shape
`maxSubarrayDc` solves the left half, the right half and the best slice that crosses the middle, and keeps the largest. `maxSubarrayKadane` carries the best sum ending
at each element. Both return `Option[Subarray]` (none for empty input) with the sum and the inclusive slice bounds. `masterCase(a, b, d)` classifies T(n) = a T(n/b) + Theta(n^d).
Module: `src/nimcs/algo/divide_conquer.nim`.

```nim
import std/options
import nimcs/algo/divide_conquer

let xs = @[-2, 1, -3, 4, -1, 2, 1, -5, 4]
doAssert maxSubarrayKadane(xs).get == Subarray(sum: 6, first: 3, last: 6)
doAssert maxSubarrayDc(xs).get.sum == 6
doAssert maxSubarrayDc(newSeq[int]()).isNone
```

```nim
import std/options
import nimcs/algo/divide_conquer

doAssert masterCase(2, 2, 1) == some(mcBalanced)   # merge sort: Theta(n log n)
doAssert masterCase(3, 2, 1) == some(mcLeaves)     # Karatsuba: Theta(n^log2 3)
doAssert masterCase(1, 2, 1) == some(mcRoot)       # Theta(n)
```

The master theorem, for a >= 1, b >= 2, d >= 0 and f(n) = Theta(n^d): if a < b^d the root dominates and T(n) = Theta(n^d); if a = b^d every level costs the same and
T(n) = Theta(n^d log n); if a > b^d the leaves dominate and T(n) = Theta(n^(log_b a)). For the maximum-subarray recursion a = 2, b = 2, d = 1, so T(n) = Theta(n log n).

## Laws and invariants
- Kadane's scan returns the hand-worked sum and slice (TECH-DC-MAXSUB-01); divide and conquer returns the same sum (TECH-DC-MAXSUB-02).
- On any non-empty array both methods and brute force agree on the sum, and each slice is in range and adds up to its sum (TECH-DC-MAXSUB-03).
- Empty input gives `none` (TECH-DC-MAXSUB-04).
- Textbook recurrences land in their master-theorem case (TECH-DC-MASTER-01); the case agrees with exact powers, never moves toward the root as a grows, and does not overflow for huge d (TECH-DC-MASTER-02).
- Invalid parameters give `none` (TECH-DC-MASTER-03).

## Complexity
`maxSubarrayDc`: Theta(n log n) time, O(log n) stack. `maxSubarrayKadane`: Theta(n) time, O(1) space. Sums are assumed not to overflow `int`.

## Pitfalls
Forgetting the crossing slice finds only slices inside one half:

```nim bad
result = max(solve(xs, lo, mid), solve(xs, mid + 1, hi))   # misses a slice that spans the middle
```

Fix: compute the best suffix of the left half and the best prefix of the right half and consider their sum, as `maxSubarrayDc` does. In the master theorem, applying the cases
when f(n) is not polynomial, or when the subproblems are unequal, is outside its scope.

## Related
`greedy.md`, `memoization.md`, `lis.md`, `knapsack.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `b6deea26499dcff1` Algorithms
- `29ca95172575b79a` Algorithms and Data Structures
- `5ea7cdc2c5670fd7` Data Structures and Algorithms
- `81c6122da5a53e33` Principles of Algorithmic Problem Solving
