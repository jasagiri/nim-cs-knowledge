import std/[algorithm, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/radix_sort

type Keyed = (int, int)   # (key, original position)

proc naturals(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(0, 100_000), 0, 40)

proc keyed(): Gen[seq[Keyed]] {.raises: [ValueError].} =
  seqOf(intIn(0, 5), 0, 24).map(proc(keys: seq[int]): seq[Keyed] {.raises: [].} =
    for i, k in keys:
      result.add (k, i))

func firstOf(x: Keyed): int {.raises: [].} = x[0]

# SPEC: SORT-RADIX-01
test "SORT-RADIX-01 Given non-negative integers, when radix sorted, then the result equals the standard library's sorted":
  let outcome = check(naturals(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    radixSort(xs) == ok(sorted(xs), SortKeyError))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SORT-RADIX-01
test "SORT-RADIX-01 Given values needing several bytes, when radix sorted, then they are ordered":
  check radixSort(@[70_000, 255, 256, 0, 65_536, 1]) == ok(@[0, 1, 255, 256, 65_536, 70_000], SortKeyError)
  check radixSort(newSeq[int]()) == ok(newSeq[int](), SortKeyError)
  check radixSort(@[high(int), 3]) == ok(@[3, high(int)], SortKeyError)

# SPEC: SORT-RADIX-02
test "SORT-RADIX-02 Given a negative number among the keys, when radix sorted, then the error says negative":
  let outcome = check(naturals(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    radixSort(xs & @[-1]) == err(seq[int], skNegative))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SORT-RADIX-03
test "SORT-RADIX-03 Given records with repeated keys, when counting sorted by key, then equal keys keep their input order":
  let outcome = check(keyed(), proc(xs: seq[Keyed]): bool {.raises: [CatchableError].} =
    let r = countingSortBy(xs, 6, firstOf)
    if not r.isOk or r.value.len != xs.len: return false
    for i in 1 ..< r.value.len:
      let (a, b) = (r.value[i - 1], r.value[i])
      if a[0] > b[0] or (a[0] == b[0] and a[1] > b[1]): return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SORT-RADIX-03
test "SORT-RADIX-03 Given integers below the bound, when counting sorted, then the result equals sorted":
  let outcome = check(seqOf(intIn(0, 9), 0, 30), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    countingSort(xs, 10) == ok(sorted(xs), SortKeyError))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SORT-RADIX-04
test "SORT-RADIX-04 Given a key outside the bound or a bad bound, when counting sorted, then the matching error is returned":
  check countingSort(@[1, 2, 10], 10) == err(seq[int], skOutOfRange)
  check countingSort(@[1, -2], 10) == err(seq[int], skNegative)
  check countingSort(@[1], 0) == err(seq[int], skBadBound)
  check countingSort(newSeq[int](), 3) == ok(newSeq[int](), SortKeyError)

# SPEC: SORT-RADIX-05
test "SORT-RADIX-05 Given any non-negative integers, when radix sorted twice, then the second sort changes nothing":
  let outcome = check(naturals(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let once = radixSort(xs)
    once.isOk and radixSort(once.value) == once)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SORT-RADIX-06
test "SORT-RADIX-06 Given a bound above the allocation cap, when counting sorted, then the error says so and nothing is allocated":
  check countingSort(@[1], high(int)) == err(seq[int], skBoundTooLarge)
  check countingSort(newSeq[int](), maxCountingBound + 1) == err(seq[int], skBoundTooLarge)
  check countingSortBy(@[1], high(int), proc(x: int): int {.noSideEffect, raises: [].} = x) == err(seq[int], skBoundTooLarge)
  check countingSort(@[2, 0, 1], 3) == ok(@[0, 1, 2], SortKeyError)
