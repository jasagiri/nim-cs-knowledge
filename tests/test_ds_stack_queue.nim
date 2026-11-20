import std/[unittest, options, algorithm]
import propcheck
import nimcs/ds/stack_queue

proc ints(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-30, 30), 0, 40)

func bruteNextGreater(xs: seq[int]): seq[Option[int]] =
  for i in 0 ..< xs.len:
    var found = none(int)
    for j in i + 1 ..< xs.len:
      if xs[j] > xs[i]:
        found = some(j)
        break
    result.add found

suite "stack_queue":
  # SPEC: DS-STACKQUEUE-01
  test "DS-STACKQUEUE-01 Given any items, when pushed and popped, then they come back in reverse order":
    let outcome = check(ints(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        var s = emptyStack[int]()
        for x in xs:
          s = s.push(x)
        var back: seq[int]
        while not s.isEmpty:
          back.add s.top.get
          s = s.pop
        back == xs.reversed)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-STACKQUEUE-02
  test "DS-STACKQUEUE-02 Given any stack and an item, when pushing then popping, then the original stack returns":
    let outcome = check(pair(ints(), intIn(-5, 5)),
      proc(t: (seq[int], int)): bool {.raises: [CatchableError].} =
        var s = emptyStack[int]()
        for x in t[0]:
          s = s.push(x)
        s.push(t[1]).pop.toSeq == s.toSeq and s.push(t[1]).top == some(t[1]))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-STACKQUEUE-03
  test "DS-STACKQUEUE-03 Given any items, when enqueued and dequeued, then they come back in the same order":
    let outcome = check(ints(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        var q = emptyQueue[int]()
        for x in xs:
          q = q.enqueue(x)
        let order = q.toSeq
        var out2: seq[int]
        while not q.isEmpty:
          out2.add q.front.get
          q = q.dequeue
        out2 == xs and order == xs)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-STACKQUEUE-04
  test "DS-STACKQUEUE-04 Given the empty stack or queue, when reading or removing, then the answer is none and it stays empty":
    let s = emptyStack[int]()
    check s.isEmpty and s.len == 0 and s.top.isNone and s.pop.isEmpty
    let q = emptyQueue[int]()
    check q.isEmpty and q.len == 0 and q.front.isNone and q.dequeue.isEmpty

  # SPEC: DS-STACKQUEUE-05
  test "DS-STACKQUEUE-05 Given a stack and a queue, when updating, then the old versions are unchanged":
    let s = emptyStack[int]().push(1).push(2)
    let s2 = s.push(3)
    let s3 = s.pop
    check s.toSeq == @[2, 1]
    check s2.toSeq == @[3, 2, 1]
    check s3.toSeq == @[1]
    let q = emptyQueue[int]().enqueue(1).enqueue(2)
    let q2 = q.enqueue(3)
    let q3 = q.dequeue
    check q.toSeq == @[1, 2]
    check q2.toSeq == @[1, 2, 3]
    check q3.toSeq == @[2]

  # SPEC: DS-STACKQUEUE-06
  test "DS-STACKQUEUE-06 Given any items, when computing next-greater indices, then they match the quadratic definition":
    let outcome = check(ints(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        nextGreaterIndex(xs) == bruteNextGreater(xs))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-STACKQUEUE-07
  test "DS-STACKQUEUE-07 Given a known list, when asking next greater values, then the textbook answer comes out":
    check nextGreater([2, 1, 2, 4, 3]) == @[some(4), some(2), some(4), none(int), none(int)]
    check nextGreater(newSeq[int]()).len == 0
    check nextGreater([5, 4, 3]) == @[none(int), none(int), none(int)]
    check nextGreater([1, 2, 3]) == @[some(2), some(3), none(int)]
    check nextGreater([3, 3]) == @[none(int), none(int)]

  # SPEC: DS-STACKQUEUE-08
  test "DS-STACKQUEUE-08 Given 200000 increasing items, when computing next-greater indices, then the first, an inner and the last answer are right":
    var xs: seq[int]
    for i in 0 ..< 200_000:
      xs.add i
    let r = nextGreaterIndex(xs)
    check r[0] == some(1)
    check r[199_998] == some(199_999)
    check r[199_999].isNone
