import std/[unittest, options, algorithm]
import propcheck
import nimcs/ds/leftist_heap

proc ints(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-30, 30), 0, 40)

suite "leftist_heap":
  # SPEC: DS-LEFTISTHEAP-01
  test "DS-LEFTISTHEAP-01 Given any items, when inserted and drained by deleteMin, then they come out sorted":
    let outcome = check(ints(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        fromSeq(xs).toSortedSeq == xs.sorted)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-LEFTISTHEAP-02
  test "DS-LEFTISTHEAP-02 Given two heaps, when merged in either order, then both hold exactly the union of their elements":
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

  # SPEC: DS-LEFTISTHEAP-03
  test "DS-LEFTISTHEAP-03 Given any items, when asking findMin, then it is the minimum and deleteMin removes one copy of it":
    let outcome = check(ints(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let h = fromSeq(xs)
        if xs.len == 0: return h.findMin.isNone and h.deleteMin.isEmpty
        let rest = xs.sorted
        h.findMin == some(rest[0]) and h.deleteMin.toSortedSeq == rest[1 .. ^1] and
          h.deleteMin.len == xs.len - 1)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-LEFTISTHEAP-04
  test "DS-LEFTISTHEAP-04 Given a heap, when inserting or deleting, then the old version is unchanged":
    let h = fromSeq([5, 1, 3])
    let a = h.insert(0)
    let b = h.deleteMin
    check h.toSortedSeq == @[1, 3, 5]
    check a.toSortedSeq == @[0, 1, 3, 5]
    check b.toSortedSeq == @[3, 5]

  # SPEC: DS-LEFTISTHEAP-05
  test "DS-LEFTISTHEAP-05 Given the empty heap, when asking for the minimum or deleting, then findMin is none and it stays empty":
    let h = emptyHeap[int]()
    check h.isEmpty
    check h.findMin.isNone
    check h.deleteMin.isEmpty
    check h.len == 0

  # SPEC: DS-LEFTISTHEAP-06
  test "DS-LEFTISTHEAP-06 Given random inserts and deleteMins, when checking the structure, then its invariants hold at every step":
    let outcome = check(seqOf(intIn(0, 9), 0, 80),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        var h = emptyHeap[int]()
        for op in ops:
          h = if op < 6: h.insert(op * 7 mod 11) else: h.deleteMin
          if not h.invariantsHold: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed


  # SPEC: DS-LEFTISTHEAP-07
  test "DS-LEFTISTHEAP-07 Given one million descending inserts, when the heap is used and dropped, then nothing overflows the stack":
    block:
      var h = emptyHeap[int]()
      for i in countdown(1_000_000, 1):
        h = h.insert(i)
      check h.findMin == some(1)
      check h.len == 1_000_000
    check true
