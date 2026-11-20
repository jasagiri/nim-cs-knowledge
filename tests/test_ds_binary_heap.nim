import std/[unittest, options, algorithm, heapqueue]
import propcheck
import nimcs/ds/binary_heap

type
  Job = object
    prio: int
    name: string

func `<`(a, b: Job): bool = a.prio < b.prio

proc ints(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-30, 30), 0, 50)

suite "binary_heap":
  # SPEC: DS-BINARYHEAP-01
  test "DS-BINARYHEAP-01 Given any items, when pushed and drained by pop, then they come out sorted":
    let outcome = check(ints(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        var h = emptyHeap[int]()
        for x in xs:
          h = h.push(x)
        var drained: seq[int]
        while not h.isEmpty:
          drained.add h.peek.get
          h = h.pop
        drained == xs.sorted)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BINARYHEAP-02
  test "DS-BINARYHEAP-02 Given any items, when built with heapify, then the heap order holds and toSortedSeq is the sorted items":
    let outcome = check(ints(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let h = heapify(xs)
        h.invariantsHold and h.len == xs.len and h.toSortedSeq == xs.sorted)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BINARYHEAP-03
  test "DS-BINARYHEAP-03 Given any items, when asking peek, then it is the minimum and pop removes one copy of it":
    let outcome = check(ints(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let h = heapify(xs)
        if xs.len == 0: return h.peek.isNone and h.pop.isEmpty
        let s = xs.sorted
        h.peek == some(s[0]) and h.pop.toSortedSeq == s[1 .. ^1] and h.pop.len == xs.len - 1)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BINARYHEAP-04
  test "DS-BINARYHEAP-04 Given a heap, when pushing or popping, then the old version is unchanged":
    let h = heapify([5, 1, 3])
    let a = h.push(0)
    let b = h.pop
    check h.toSortedSeq == @[1, 3, 5]
    check a.toSortedSeq == @[0, 1, 3, 5]
    check b.toSortedSeq == @[3, 5]

  # SPEC: DS-BINARYHEAP-05
  test "DS-BINARYHEAP-05 Given the empty heap, when peeking or popping, then peek is none and it stays empty":
    let h = emptyHeap[int]()
    check h.isEmpty and h.len == 0
    check h.peek.isNone
    check h.pop.isEmpty
    check heapify(newSeq[int]()).isEmpty

  # SPEC: DS-BINARYHEAP-06
  test "DS-BINARYHEAP-06 Given random pushes and pops, when checking the layout, then no item is smaller than its parent at every step":
    let outcome = check(seqOf(intIn(0, 9), 0, 100),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        var h = emptyHeap[int]()
        for op in ops:
          h = if op < 6: h.push(op * 7 mod 11) else: h.pop
          if not h.invariantsHold: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BINARYHEAP-07
  test "DS-BINARYHEAP-07 Given any items, when compared with std/heapqueue, then both drain in the same order":
    let outcome = check(ints(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        var q = initHeapQueue[int]()
        for x in xs:
          q.push x
        var fromQueue: seq[int]
        while q.len > 0:
          fromQueue.add q.pop
        heapify(xs).toSortedSeq == fromQueue)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BINARYHEAP-08
  test "DS-BINARYHEAP-08 Given items with equal keys, when sorted through the heap, then the keys are in order":
    let h = heapify([Job(prio: 2, name: "b"), Job(prio: 1, name: "a"), Job(prio: 2, name: "c")])
    let order = h.toSortedSeq
    check order[0].name == "a"
    check order[1].prio == 2 and order[2].prio == 2
