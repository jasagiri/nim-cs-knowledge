# Backtracking

## Intent
Build solutions one choice at a time, abandoning a partial solution as soon as it cannot lead anywhere. Described as data, a search is
a start state, a function that lists the ways to extend a state, and a test for "this state is a solution"; the walk through the tree is
the same every time.

## Use when / avoid when
- Use it for constraint problems with a small tree: permutations, combinations, n-queens, puzzles.
- Put the pruning inside `children`: list only extensions that can still succeed; that is where the speed comes from.
- Use dynamic programming (`memoization.md`, `knapsack.md`) when sub-problems repeat; backtracking would redo them.
- Use `firstSolution` when one answer is enough; use `greedy.md` when a local rule is provably optimal.

## Nim shape
`backtrack(start, children, accept)` is a pure generator: it returns every accepted state in pre-order, left to right, collecting into a local
`var` inside the walk. Domain helpers (`permutations`, `combinations`, `nQueens`) return `Option`, with `none` for negative or oversized arguments
(the limits are exported constants). Module: `src/nimcs/algo/backtracking.nim`.

```nim
import std/options
import nimcs/algo/backtracking

doAssert permutations(3).get.len == 6
doAssert combinations(4, 2).get == @[@[0, 1], @[0, 2], @[0, 3], @[1, 2], @[1, 3], @[2, 3]]
doAssert nQueens(6).get.len == 4
doAssert nQueens(-1).isNone
```

A custom search: all binary strings of length 3 with no two adjacent ones.

```nim
import nimcs/algo/backtracking

func kids(s: string): seq[string] {.raises: [].} =
  if s.len >= 3: return @[]
  result = @[s & "0"]
  if s.len == 0 or s[^1] != '1':
    result.add s & "1"

func complete(s: string): bool {.raises: [].} = s.len == 3

doAssert backtrack("", kids, complete) == @["000", "001", "010", "100", "101"]
```

## Laws and invariants
- `backtrack` returns accepted states in pre-order, left-to-right order (TECH-BT-GEN-01); the same arguments give the same list (TECH-BT-GEN-02).
- `firstSolution` is the head of that list, or `none` (TECH-BT-GEN-03).
- `permutations(n)` has n! distinct entries in lexicographic order (TECH-BT-PERM-01), each a rearrangement of 0..n-1 (TECH-BT-PERM-02).
- `combinations(n, k)` has C(n, k) ascending subsets in lexicographic order (TECH-BT-COMB-01).
- n-queens counts are 1, 1, 0, 0, 2, 10, 4, 40, 92 for n = 0..8 and every solution is attack-free (TECH-BT-QUEENS-01, TECH-BT-QUEENS-02).
- Negative or oversized arguments give `none` (TECH-BT-PERM-03, TECH-BT-COMB-02).

## Complexity
Worst case exponential in the depth of the tree (n! permutations, C(n, k) combinations). Pruning in `children` cuts the visited nodes, not the worst-case bound. Space is the depth of the recursion plus the solutions collected.

## Pitfalls
Mutating a shared partial solution and forgetting to undo it corrupts the siblings:

```nim bad
var path: seq[int]
proc go(n: int) =
  for v in 0 ..< n:
    path.add v
    go(n - 1)          # missing path.setLen(path.len - 1): the next sibling sees v
```

Fix: states are values; `children` returns new states (`s & @[v]`), so there is nothing to undo. Also, a solution test that is true at an
inner node does not stop the walk below it; make `children` empty at a complete state if extensions are not wanted.

## Related
`knapsack.md`, `greedy.md`, `memoization.md`, `sieve.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `bde3b4eb1016bf2e` 30 Days of Elixir
- `73d14d6fafde7152` Advanced Functional Programming in Haskell
- `6f31dd50eef1beba` Algorithmic Thinking
- `b6deea26499dcff1` Algorithms
- `c1b93dc13846e70a` Algorithms Course Materials
- `b609569e40e49e47` Analysis of Algorithms (CSE 373)
- `63ad3e14455a34af` Competitive Programmer's Handbook
- `5ea7cdc2c5670fd7` Data Structures and Algorithms
