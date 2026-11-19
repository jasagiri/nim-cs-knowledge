# 0/1 knapsack

## Intent
Choose some of a set of items, each at most once, to maximise total value while the total weight stays within a
capacity. Let `best[i][c]` be the best value using the first `i` items with capacity `c`; item `i` is either skipped or, if it fits, taken.

## Use when / avoid when
- Use it for budgeted selection with integer weights (cargo, feature selection under a time budget).
- Use a greedy value-per-weight rule only for the fractional version; it is wrong for 0/1 items (`fractionalKnapsack` in `greedy.md` is that version).
- Avoid the table when the capacity is huge: the cost is proportional to the capacity (pseudo-polynomial); use branch and bound or an approximation.

## Nim shape
`item(weight, value)` is a smart constructor returning `Option[Item]`; `knapsack(items, capacity)` returns `Option[Packing]`
with the value, the total weight and the indices chosen, ascending. Negative inputs give `none`, and so does a table larger than `maxTableCells` (100 million cells), so a huge capacity cannot exhaust memory. Module: `src/nimcs/algo/knapsack.nim`.

```nim
import std/options
import nimcs/algo/knapsack

let items = [Item(weight: 1, value: 1), Item(weight: 3, value: 4),
             Item(weight: 4, value: 5), Item(weight: 5, value: 7)]
let packing = knapsack(items, 7).get
doAssert packing.value == 9
doAssert packing.chosen == @[1, 2]
doAssert knapsack(items, -1).isNone
```

## Laws and invariants
- The value equals the best over all subsets, checked by brute force (DP-KNAP-02).
- The chosen indices are valid and ascending, fit the capacity, and add up to the reported weight and value (DP-KNAP-03).
- A negative capacity, weight or value gives `none` (DP-KNAP-04); a capacity whose table would exceed `maxTableCells` gives `none` too (DP-KNAP-06).
- The answer is repeatable, and one more unit of capacity never lowers the value (DP-KNAP-05).
- A classic instance gives the hand-worked result (DP-KNAP-01).

## Complexity
Time and space O(n * capacity). The whole table is kept so the chosen items can be recovered by walking back; computing only the value needs O(capacity) space.

## Pitfalls
Updating a one-dimensional table in increasing capacity order lets an item be used more than once (it becomes
unbounded knapsack):

```nim bad
for it in items:
  for c in it.weight .. capacity:           # ascending: the item can be reused
    best[c] = max(best[c], best[c - it.weight] + it.value)
```

Fix: loop capacity downwards when compressing to one row, or keep the two-dimensional table as `knapsack` does.
Also remember that totals are assumed not to overflow `int`.

## Related
`memoization.md`, `greedy.md`, `backtracking.md` (the exhaustive alternative), `lis.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `6f31dd50eef1beba` Algorithmic Thinking
- `61811291625a13a9` Algorithms for Competitive Programming
- `a8882bbba7213b23` Algorithms Notes for Professionals
- `63ad3e14455a34af` Competitive Programmer's Handbook
- `5ea7cdc2c5670fd7` Data Structures and Algorithms
- `e8a751ae9f8ed52b` Learning Algorithm
- `fd559bc6baa61a32` The Design of Approximation Algorithms
