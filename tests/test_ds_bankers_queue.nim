import std/[unittest, options]
import propcheck
import nimcs/ds/bankers_queue

proc ints(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-50, 50), 0, 40)

suite "bankers_queue":
  # SPEC: DS-BANKERSQUEUE-01
  test "DS-BANKERSQUEUE-01 Given any items, when pushed in order and popped until empty, then they leave in the same order":
    let outcome = check(ints(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        var q = fromSeq(xs)
        var drained: seq[int]
        while not q.isEmpty:
          drained.add q.peek.get
          q = q.pop
        drained == xs and fromSeq(xs).toSeq == xs)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BANKERSQUEUE-02
  test "DS-BANKERSQUEUE-02 Given the empty queue, when peeking or popping, then peek is none and pop stays empty":
    let q = emptyQueue[int]()
    check q.peek.isNone
    check q.pop.isEmpty
    check q.len == 0

  # SPEC: DS-BANKERSQUEUE-03
  test "DS-BANKERSQUEUE-03 Given a queue, when pushing or popping, then the old version is unchanged":
    let q = fromSeq([1, 2, 3])
    let pushed = q.push(4)
    let popped = q.pop
    check q.toSeq == @[1, 2, 3]
    check pushed.toSeq == @[1, 2, 3, 4]
    check popped.toSeq == @[2, 3]
    check popped.pop.pop.isEmpty
    check q.pop.toSeq == @[2, 3]

  # SPEC: DS-BANKERSQUEUE-04
  test "DS-BANKERSQUEUE-04 Given a random sequence of pushes and pops, when compared with a seq model, then contents and length agree at every step":
    let outcome = check(seqOf(intIn(0, 9), 0, 80),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        var q = emptyQueue[int]()
        var model: seq[int]
        for op in ops:
          if op < 6:
            q = q.push(op)
            model.add op
          else:
            q = q.pop
            if model.len > 0: model.delete(0)
          if q.toSeq != model or q.len != model.len: return false
          if q.peek != (if model.len > 0: some(model[0]) else: none(int)): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BANKERSQUEUE-05
  test "DS-BANKERSQUEUE-05 Given a large queue, when filled and drained, then all elements come out in order":
    var q = emptyQueue[int]()
    for i in 0 ..< 5000:
      q = q.push(i)
    check q.len == 5000
    var next = 0
    while not q.isEmpty:
      check q.peek == some(next)
      q = q.pop
      inc next
    check next == 5000
