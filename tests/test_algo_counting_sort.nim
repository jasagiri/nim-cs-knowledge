import std/[algorithm, sequtils, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/counting_sort
import nimcs/algo/radix_sort

type Keyed = (int, int)   # (key, original position)

proc ints(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-20, 20), 0, 50)

proc keyed(): Gen[seq[Keyed]] {.raises: [ValueError].} =
  seqOf(intIn(-3, 3), 0, 30).map(proc(keys: seq[int]): seq[Keyed] {.raises: [].} =
    for i, k in keys:
      result.add (k, i))

func firstOf(x: Keyed): int {.raises: [].} = x[0]

# SPEC: SORT-COUNTING-01
test "SORT-COUNTING-01 Given integers inside the stated range, when counting sorted, then the result equals the standard library's sorted":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    countingSortRange(xs, -20, 20) == ok(sorted(xs), CountingError))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SORT-COUNTING-01
test "SORT-COUNTING-01 Given a range that is wider than the data or a single value, when sorted, then the order is still right":
  check countingSortRange(@[3, -1, 2, -1], -5, 10) == ok(@[-1, -1, 2, 3], CountingError)
  check countingSortRange(@[7, 7, 7], 7, 7) == ok(@[7, 7, 7], CountingError)
  check countingSortRange(newSeq[int](), 0, 0) == ok(newSeq[int](), CountingError)
  check countingSortRange(@[low(int) + 1, low(int)], low(int), low(int) + 1) == ok(@[low(int), low(int) + 1], CountingError)

# SPEC: SORT-COUNTING-02
test "SORT-COUNTING-02 Given records with repeated keys, when counting sorted by key, then equal keys keep their input order":
  let outcome = check(keyed(), proc(xs: seq[Keyed]): bool {.raises: [CatchableError].} =
    let got = countingSortByRange(xs, -3, 3, firstOf)
    # the reference: the standard library's stable sort by key
    got == ok(xs.sortedByIt(it[0]), CountingError))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SORT-COUNTING-03
test "SORT-COUNTING-03 Given a key below or above the range, when sorted, then the error says out of range":
  check countingSortRange(@[1, 2, 3], 2, 3) == err(seq[int], ceOutOfRange)
  check countingSortRange(@[1, 2, 4], 1, 3) == err(seq[int], ceOutOfRange)
  check keyHistogram(@[0, 5], 0, 4) == err(seq[int], ceOutOfRange)

# SPEC: SORT-COUNTING-04
test "SORT-COUNTING-04 Given a reversed or oversized range, when sorted, then each gives its own error and the largest allowed range is accepted":
  check countingSortRange(@[1], 3, 2) == err(seq[int], ceBadRange)
  check countingSortRange(@[1], 0, high(int)) == err(seq[int], ceRangeTooLarge)
  check countingSortRange(@[1], low(int), high(int)) == err(seq[int], ceRangeTooLarge)
  check countingSortRange(@[1], -maxCountingSpan, maxCountingSpan) == err(seq[int], ceRangeTooLarge)
  check countingSortRange(@[0], 0, maxCountingSpan - 1) == ok(@[0], CountingError)
  check countingSortRange(@[0], 0, maxCountingSpan) == err(seq[int], ceRangeTooLarge)
  check keyHistogram(@[1], 2, 1) == err(seq[int], ceBadRange)

# SPEC: SORT-COUNTING-05
test "SORT-COUNTING-05 Given keys and a range, when the histogram is asked, then each entry is the number of occurrences of its key":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let h = keyHistogram(xs, -20, 20)
    if not h.isOk or h.value.len != 41: return false
    var total = 0
    for i, c in h.value:
      total += c
      if c != xs.count(i - 20): return false
    total == xs.len)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SORT-COUNTING-06
test "SORT-COUNTING-06 Given any integers with a small spread, when sorted with the range found automatically, then the result equals sorted":
  let outcome = check(seqOf(intIn(-1_000_000, 1_000_000), 0, 60), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    countingSortAuto(xs) == ok(sorted(xs), CountingError))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SORT-COUNTING-06
test "SORT-COUNTING-06 Given values too far apart, when sorted automatically, then the error says the range is too large":
  check countingSortAuto(@[0, high(int)]) == err(seq[int], ceRangeTooLarge)
  check countingSortAuto(newSeq[int]()) == ok(newSeq[int](), CountingError)

# SPEC: SORT-COUNTING-07
test "SORT-COUNTING-07 Given any integers, when counting sorted twice, then the second sort changes nothing":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let once = countingSortRange(xs, -20, 20).value
    countingSortRange(once, -20, 20) == ok(once, CountingError))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: SORT-COUNTING-08
test "SORT-COUNTING-08 Given non-negative integers, when counting sorted and radix sorted, then both agree":
  let outcome = check(seqOf(intIn(0, 100_000), 0, 40), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let radix = radixSort(xs)
    let counting = countingSortAuto(xs)
    radix.isOk and counting.isOk and radix.value == counting.value)
  checkpoint describe(outcome)
  check outcome.passed
