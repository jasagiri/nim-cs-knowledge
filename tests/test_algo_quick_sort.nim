import std/[algorithm, unittest]
import propcheck
import nimcs/algo/quick_sort

type Keyed = (int, int)   # (key, original position)

func keyLess(a, b: Keyed): bool {.raises: [].} = a[0] < b[0]

proc ints(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-20, 20), 0, 30)

proc keyed(): Gen[seq[Keyed]] {.raises: [ValueError].} =
  seqOf(intIn(0, 4), 0, 24).map(proc(keys: seq[int]): seq[Keyed] {.raises: [].} =
    for i, k in keys:
      result.add (k, i))

# SPEC: SORT-QUICK-01
test "SORT-QUICK-01 Given any integers, when sorted, then the result equals the standard library's sorted":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    quickSort(xs) == sorted(xs))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SORT-QUICK-02
test "SORT-QUICK-02 Given any integers, when sorted with a descending order, then the result is the ascending result reversed":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    quickSort(xs, proc(a, b: int): bool {.noSideEffect, raises: [].} = a > b) == sorted(xs, SortOrder.Descending))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SORT-QUICK-03
test "SORT-QUICK-03 Given any integers, when sorted twice, then the second sort changes nothing":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let once = quickSort(xs)
    quickSort(once) == once)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SORT-QUICK-04
test "SORT-QUICK-04 Given an empty or one-element input, when sorted, then the input comes back":
  check quickSort(newSeq[int]()) == newSeq[int]()
  check quickSort(@[7]) == @[7]
  check quickSort(@["b", "a"]) == @["a", "b"]

# SPEC: SORT-QUICK-05
test "SORT-QUICK-05 Given records with repeated keys, when sorted by key, then records with equal keys keep their input order":
  let outcome = check(keyed(), proc(xs: seq[Keyed]): bool {.raises: [CatchableError].} =
    let r = quickSort(xs, keyLess)
    if r.len != xs.len: return false
    for i in 1 ..< r.len:
      if r[i - 1][0] > r[i][0]: return false
      if r[i - 1][0] == r[i][0] and r[i - 1][1] > r[i][1]: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed
