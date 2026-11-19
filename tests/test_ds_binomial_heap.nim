import std/[unittest, options, algorithm]
import propcheck
import nimcs/ds/binomial_heap

proc ints(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-30, 30), 0, 40)

suite "binomial_heap":
  # SPEC: DS-BINOMIALHEAP-01
  test "DS-BINOMIALHEAP-01 Given any items, when inserted and drained by deleteMin, then they come out sorted":
    let outcome = check(ints(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        fromSeq(xs).toSortedSeq == xs.sorted)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BINOMIALHEAP-02
  test "DS-BINOMIALHEAP-02 Given two heaps, when merged in either order, then both hold exactly the union of their elements":
    let outcome = check(pair(ints(), ints()),
      proc(t: (seq[int], seq[int])): bool {.raises: [CatchableError].} =
        let a = fromSeq(t[0])
        let b = fromSeq(t[1])
        let both = (t[0] & t[1]).sorted
        a.merge(b).toSortedSeq == both and b.merge(a).toSortedSeq == both and
          a.merge(b).len == both.len and
          a.merge(emptyHeap[int]()).toSortedSeq == t[0].sorted)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BINOMIALHEAP-03
  test "DS-BINOMIALHEAP-03 Given any items, when asking findMin, then it is the minimum and deleteMin removes one copy of it":
    let outcome = check(ints(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let h = fromSeq(xs)
        if xs.len == 0: return h.findMin.isNone and h.deleteMin.isEmpty
        let rest = xs.sorted
        h.findMin == some(rest[0]) and h.deleteMin.toSortedSeq == rest[1 .. ^1] and
          h.deleteMin.len == xs.len - 1)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BINOMIALHEAP-04
  test "DS-BINOMIALHEAP-04 Given a heap, when inserting or deleting, then the old version is unchanged":
    let h = fromSeq([5, 1, 3])
    let a = h.insert(0)
    let b = h.deleteMin
    check h.toSortedSeq == @[1, 3, 5]
    check a.toSortedSeq == @[0, 1, 3, 5]
    check b.toSortedSeq == @[3, 5]

  # SPEC: DS-BINOMIALHEAP-05
  test "DS-BINOMIALHEAP-05 Given the empty heap, when asking for the minimum or deleting, then findMin is none and it stays empty":
    let h = emptyHeap[int]()
    check h.isEmpty
    check h.findMin.isNone
    check h.deleteMin.isEmpty
    check h.len == 0

  # SPEC: DS-BINOMIALHEAP-06
  test "DS-BINOMIALHEAP-06 Given random inserts and deleteMins, when checking the structure, then its invariants hold at every step":
    let outcome = check(seqOf(intIn(0, 9), 0, 80),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        var h = emptyHeap[int]()
        for op in ops:
          h = if op < 6: h.insert(op * 7 mod 11) else: h.deleteMin
          if not h.invariantsHold: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BINOMIALHEAP-07
  test "DS-BINOMIALHEAP-07 Given a heap of n elements, when listing tree ranks, then they are the set bits of n":
    for n in 0 .. 70:
      var h = emptyHeap[int]()
      for i in 0 ..< n: h = h.insert(i)
      var bits: seq[int]
      for b in 0 .. 8:
        if ((n shr b) and 1) == 1: bits.add b
      check h.rankProfile == bits

