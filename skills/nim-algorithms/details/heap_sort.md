# Heap sort

## Intent

Arrange the array as a max-heap (each parent not less than its children), then repeatedly swap the root with the last unsorted slot and restore the heap on the shorter prefix. It sorts in place inside its own copy.

## Use when / avoid when

- Use when: you need an O(n log n) worst case and little extra memory, and stability does not matter.
- Avoid when: equal elements must keep their order; use `merge_sort`.
- Avoid when: the data is small or nearly sorted; `insertion_sort` is faster.

## Nim shape

`src/nimcs/algo/heap_sort.nim`: a private `siftDown` (mutates a local `var seq`) and the public `heapSort`.

```nim
import nimcs/algo/heap_sort

assert heapSort(@[4, 10, 3, 5, 1]) == @[1, 3, 4, 5, 10]
assert heapSort(@["b", "c", "a"]) == @["a", "b", "c"]
```

## Laws and invariants

- `heapSort(xs) == sorted(xs)` for integers (SORT-HEAP-01).
- A descending comparator gives the input sorted descending (SORT-HEAP-02).
- Idempotent (SORT-HEAP-03); empty and one-element inputs are unchanged (SORT-HEAP-04).
- Sorting records by key gives ascending keys and loses no record; equal-key order is not promised (SORT-HEAP-05).

## Complexity

- Time: O(n log n) in every case (building the heap is O(n)). Space: O(n) for the copy, O(1) beyond it.

## Pitfalls

Assuming a sort by a key keeps equal keys in input order. Heap sort does not.

```nim bad
let byAge = heapSort(people, proc(a, b: Person): bool {.noSideEffect, raises: [].} = a.age < b.age)
# people with the same age may come out in any order
```

If ties must be ordered, sort with a total order (compare the tie-breaker too) or use `merge_sort`, which is stable.

## Related

- `merge_sort.nim`, `quick_sort.nim`, `insertion_sort.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `29ca95172575b79a` Algorithms and Data Structures
- `a8882bbba7213b23` Algorithms Notes for Professionals
- `b609569e40e49e47` Analysis of Algorithms (CSE 373)
- `c6a234b79d2a7c88` Computer Science II
- `19250093425bb17e` Data Structures and Algorithm Analysis in C++
- `cb7c39b58c54bd29` Data Structures and Algorithm Analysis in Java
- `e8a751ae9f8ed52b` Learning Algorithm
- `6f359c1814ec309e` Princeton University Algorithms, Part 1
