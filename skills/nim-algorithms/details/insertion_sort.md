# Insertion sort

## Intent

Keep a sorted prefix and slide each next element left until it sits after everything not larger than it. It is the sort you can write without thinking, and the one that real library sorts use for short slices.

## Use when / avoid when

- Use when: the input has a few dozen elements, or is nearly sorted (cost is O(n + inversions)).
- Use when: you need a stable sort and have no spare memory for merge buffers.
- Avoid when: the input is large and random; reach for `merge_sort` (stable) or `heap_sort` (worst-case bound).

## Nim shape

One module, `src/nimcs/algo/insertion_sort.nim`. The routine copies the input into a local `var`, shifts elements in that copy and returns it, so the caller's data is never touched. The comparator overload takes a strict `less`; the plain overload uses `<`.

```nim
import nimcs/algo/insertion_sort

let words = @["pear", "fig", "apple", "kiwi"]
let byLength = insertionSort(words,
  proc(a, b: string): bool {.noSideEffect, raises: [].} = a.len < b.len)
assert byLength == @["fig", "pear", "kiwi", "apple"]   # "pear" stays before "kiwi"
assert insertionSort(@[3, 1, 2]) == @[1, 2, 3]
```

## Laws and invariants

- Sorted, and a permutation of the input: `insertionSort(xs) == sorted(xs)` for integers (SORT-INSERT-01).
- A descending comparator gives the input sorted descending (SORT-INSERT-02).
- Idempotent: sorting a sorted result changes nothing (SORT-INSERT-03).
- Empty and one-element inputs come back unchanged (SORT-INSERT-04).
- Stable: elements equal under `less` keep their input order (SORT-INSERT-05).

## Complexity

- Time: O(n^2) worst and average, O(n) when already sorted. Space: O(n) for the returned copy, O(1) beyond it.

## Pitfalls

The comparator is a strict `less` (`less(a, b)` means "a must come before b"); never write `<=`. With `<=` the inner loop also shifts equal elements and the sort stops being stable.

```nim bad
while j > 0 and item <= sorted[j - 1]:   # shifts equal items past each other: not stable
  sorted[j] = sorted[j - 1]
  dec j
```

The fix is the strict comparison the module uses: `less(item, sorted[j - 1])`.

## Related

- `merge_sort.nim` (stable, O(n log n)), `heap_sort.nim`, `quick_sort.nim`, `radix_sort.nim`, `binary_search.nim` (needs sorted input).

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `a8882bbba7213b23` Algorithms Notes for Professionals
- `464f1aa168823232` Computer Science I
- `1cbc332178e5a52f` Data-Oriented Design
- `ed8c50dad686e4d3` Elementary Algorithms
- `e8a751ae9f8ed52b` Learning Algorithm
- `6f359c1814ec309e` Princeton University Algorithms, Part 1
- `81c6122da5a53e33` Principles of Algorithmic Problem Solving
