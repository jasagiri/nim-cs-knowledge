import std/[algorithm, sequtils, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/elementary_sorts
import nimcs/algo/insertion_sort

type Keyed = (int, int)   # (key, original position)

proc ints(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-30, 30), 0, 60)

proc gapLists(): Gen[seq[int]] {.raises: [ValueError].} =
  ## Strictly descending positive gaps ending in 1.
  seqOf(intIn(2, 12), 0, 4).map(proc(xs: seq[int]): seq[int] {.raises: [].} =
    xs.deduplicate.sorted(SortOrder.Descending) & @[1])

func byKey(a, b: Keyed): bool {.raises: [].} = a[0] < b[0]

func descending(a, b: int): bool {.raises: [].} = a > b

func stableReference(xs: seq[Keyed]): seq[Keyed] {.raises: [].} =
  xs.sortedByIt(it[0])

# pinned witnesses of instability: in each, the two equal keys end in the opposite order
const witness = @[(1, 0), (0, 1), (0, 2)]            # for shellsort with the gaps 2, 1
const selectionWitness = @[(2, 0), (2, 1), (1, 2)]   # for selection sort

# SPEC: ELEMSORT-SELECT-01
test "ELEMSORT-SELECT-01 Given any integers, when selection sorted, then the result equals the standard library's sorted":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    selectionSort(xs) == sorted(xs))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: ELEMSORT-SELECT-02
test "ELEMSORT-SELECT-02 Given any integers, when selection sorted with a descending comparator, then the result is sorted descending":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    selectionSort(xs, descending) == sorted(xs, SortOrder.Descending))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: ELEMSORT-SELECT-03
test "ELEMSORT-SELECT-03 Given any integers, when selection sorted, then at most len - 1 swaps are made, and none when already sorted":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let swaps = selectionSwaps(xs, proc(a, b: int): bool {.noSideEffect, raises: [].} = a < b)
    swaps <= max(0, xs.len - 1) and
      selectionSwaps(sorted(xs), proc(a, b: int): bool {.noSideEffect, raises: [].} = a < b) == 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: ELEMSORT-SELECT-04
test "ELEMSORT-SELECT-04 Given equal keys, when selection sorted, then their order may change, unlike insertion sort":
  check selectionSort(selectionWitness, byKey) == @[(1, 2), (2, 1), (2, 0)]
  check insertionSort(selectionWitness, byKey) == @[(1, 2), (2, 0), (2, 1)]

# SPEC: ELEMSORT-SELECT-05
test "ELEMSORT-SELECT-05 Given an empty or one-element input, or an already sorted result, when selection sorted, then nothing changes":
  check selectionSort(newSeq[int]()).len == 0
  check selectionSort(@[4]) == @[4]
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let once = selectionSort(xs)
    selectionSort(once) == once)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: ELEMSORT-SHELL-01
test "ELEMSORT-SHELL-01 Given any integers, when shell sorted, then the result equals the standard library's sorted":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    shellSort(xs) == sorted(xs) and shellSort(xs, descending) == sorted(xs, SortOrder.Descending))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: ELEMSORT-SHELL-01
test "ELEMSORT-SHELL-01 Given a longer input that uses several gaps, when shell sorted, then it is sorted":
  var xs: seq[int]
  for i in 0 ..< 500:
    xs.add (i * 7919) mod 1009         # a fixed scramble, 500 elements: gaps 121, 40, 13, 4, 1
  check shellGaps(xs.len) == @[121, 40, 13, 4, 1]
  check shellSort(xs) == sorted(xs)

# SPEC: ELEMSORT-SHELL-02
test "ELEMSORT-SHELL-02 Given any valid gap sequence, when shell sorted with it, then the result is sorted":
  let outcome = check(pair(ints(), gapLists()), proc(c: (seq[int], seq[int])): bool {.raises: [CatchableError].} =
    shellSortWithGaps(c[0], c[1], proc(a, b: int): bool {.noSideEffect, raises: [].} = a < b) ==
      ok(sorted(c[0]), GapError))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: ELEMSORT-SHELL-03
test "ELEMSORT-SHELL-03 Given equal keys and the gaps 2, 1, when shell sorted, then their order may change, unlike insertion sort":
  check shellSortWithGaps(witness, [2, 1], byKey) == ok(@[(0, 2), (0, 1), (1, 0)], GapError)
  check insertionSort(witness, byKey) == @[(0, 1), (0, 2), (1, 0)]
  check stableReference(witness) == @[(0, 1), (0, 2), (1, 0)]

# SPEC: ELEMSORT-SHELL-03
test "ELEMSORT-SHELL-03 Given the default gaps and fifteen records, when shell sorted, then equal keys can be reordered":
  let records = @[0, 2, 0, 1, 0, 1, 1, 1, 2, 1, 0, 0, 1, 0, 1].pairs.toSeq.mapIt((it[1], it[0]))
  check shellGaps(records.len) == @[4, 1]
  check shellSort(records, byKey) != stableReference(records)
  check shellSort(records, byKey).mapIt(it[0]) == stableReference(records).mapIt(it[0])

# SPEC: ELEMSORT-SHELL-04
test "ELEMSORT-SHELL-04 Given any size, when the default gaps are asked, then they are Knuth's, strictly descending, below n div 3 and end in 1":
  let outcome = check(intIn(-3, 5000), proc(n: int): bool {.raises: [CatchableError].} =
    let gaps = shellGaps(n)
    if gaps.len == 0 or gaps[^1] != 1: return false
    for i, g in gaps:
      if i > 0 and (g >= gaps[i - 1] or gaps[i - 1] != 3 * g + 1): return false
      if g != 1 and g >= n div 3: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed
  check shellGaps(1000) == @[121, 40, 13, 4, 1]
  check shellGaps(3) == @[1]

# SPEC: ELEMSORT-SHELL-05
test "ELEMSORT-SHELL-05 Given an empty, non-positive, non-descending or non-1-ending gap list, when asked, then each has its own error":
  let less = proc(a, b: int): bool {.noSideEffect, raises: [].} = a < b
  check shellSortWithGaps(@[2, 1], newSeq[int](), less) == err(seq[int], gapNone)
  check shellSortWithGaps(@[2, 1], [3, 0], less) == err(seq[int], gapNotPositive)
  check shellSortWithGaps(@[2, 1], [-1, 1], less) == err(seq[int], gapNotPositive)
  check shellSortWithGaps(@[2, 1], [1, 3], less) == err(seq[int], gapNotDescending)
  check shellSortWithGaps(@[2, 1], [3, 3, 1], less) == err(seq[int], gapNotDescending)
  check shellSortWithGaps(@[2, 1], [4, 2], less) == err(seq[int], gapNoFinalOne)

# SPEC: ELEMSORT-SHELL-06
test "ELEMSORT-SHELL-06 Given an empty or one-element input, or an already sorted result, when shell sorted, then nothing changes":
  check shellSort(newSeq[int]()).len == 0
  check shellSort(@[4]) == @[4]
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let once = shellSort(xs)
    shellSort(once) == once)
  checkpoint describe(outcome)
  check outcome.passed
