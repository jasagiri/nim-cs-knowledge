# Merge sort

## Intent

Sort runs of width 1, 2, 4, ... by merging neighbouring sorted runs into a second buffer, then swap buffers. The merge takes from the left run unless the right element is strictly smaller, which is what makes it stable.

## Use when / avoid when

- Use when: you need a stable sort with a guaranteed O(n log n) worst case.
- Use when: deep recursion is a worry: this version is iterative.
- Avoid when: memory is tight (it needs a second buffer); `heap_sort` sorts with O(1) extra space.
- Avoid when: the input is tiny; `insertion_sort` has less overhead.

## Nim shape

`src/nimcs/algo/merge_sort.nim` has a private `mergeRuns` (writes into a `var` buffer, private to the module) and the public `mergeSort`, a `func` that returns a new `seq`.

```nim
import nimcs/algo/merge_sort

type Entry = tuple[priority: int, name: string]

let entries = @[(2, "b"), (1, "x"), (2, "a"), (1, "y")]
let sorted = mergeSort(entries,
  proc(a, b: Entry): bool {.noSideEffect, raises: [].} = a.priority < b.priority)
assert sorted == @[(1, "x"), (1, "y"), (2, "b"), (2, "a")]   # ties keep input order
```

## Laws and invariants

- `mergeSort(xs) == sorted(xs)` for integers (SORT-MERGE-01).
- A descending comparator gives the input sorted descending (SORT-MERGE-02).
- Idempotent (SORT-MERGE-03); empty and one-element inputs are unchanged (SORT-MERGE-04).
- Stable: equal elements keep their input order (SORT-MERGE-05).

## Complexity

- Time: O(n log n) in every case. Space: O(n) for the two buffers.

## Pitfalls

The comparator is a strict `less` (`less(a, b)` means "a must come before b"); never write `<=`. Taking from the right run on `<=` (or from the left only when `less(left, right)`) reverses equal elements.

```nim bad
if not less(src[i], src[j]):   # equal elements: takes the right one first, so ties reverse
  dst[k] = src[j]
```

The fix: take the right element only when `less(src[j], src[i])`.

## Related

- `insertion_sort.nim`, `quick_sort.nim`, `heap_sort.nim`, `radix_sort.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `29ca95172575b79a` Algorithms and Data Structures
- `a8882bbba7213b23` Algorithms Notes for Professionals
- `473f0313d72c526b` Algorithms, 4th Edition
- `b609569e40e49e47` Analysis of Algorithms (CSE 373)
- `464f1aa168823232` Computer Science I
- `c6a234b79d2a7c88` Computer Science II
- `19250093425bb17e` Data Structures and Algorithm Analysis in C++
- `cb7c39b58c54bd29` Data Structures and Algorithm Analysis in Java
