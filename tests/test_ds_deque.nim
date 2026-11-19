import std/[unittest, options, algorithm]
import propcheck
import nimcs/ds/deque

suite "deque":
  # SPEC: DS-DEQUE-01
  test "DS-DEQUE-01 Given any items, when pushed at the back, then toSeq is the items in order":
    let outcome = check(seqOf(intIn(-50, 50), 0, 40),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        fromSeq(xs).toSeq == xs)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-DEQUE-02
  test "DS-DEQUE-02 Given any items, when pushed at the front, then toSeq is the items reversed":
    let outcome = check(seqOf(intIn(-50, 50), 0, 40),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        var d = emptyDeque[int]()
        for x in xs: d = d.pushFront(x)
        d.toSeq == xs.reversed)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-DEQUE-03
  test "DS-DEQUE-03 Given random operations at both ends, when compared with a seq model, then contents, ends and length agree":
    let outcome = check(seqOf(intIn(0, 9), 0, 100),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        var d = emptyDeque[int]()
        var model: seq[int]
        for i, op in ops:
          case op mod 4
          of 0:
            d = d.pushFront(i)
            model.insert(i, 0)
          of 1:
            d = d.pushBack(i)
            model.add i
          of 2:
            d = d.popFront
            if model.len > 0: model.delete(0)
          else:
            d = d.popBack
            if model.len > 0: model.setLen(model.len - 1)
          if d.toSeq != model or d.len != model.len: return false
          if d.peekFront != (if model.len > 0: some(model[0]) else: none(int)): return false
          if d.peekBack != (if model.len > 0: some(model[^1]) else: none(int)): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-DEQUE-04
  test "DS-DEQUE-04 Given a deque, when pushing or popping, then the old version is unchanged":
    let d = fromSeq([1, 2, 3])
    let a = d.pushFront(0)
    let b = d.popBack
    check d.toSeq == @[1, 2, 3]
    check a.toSeq == @[0, 1, 2, 3]
    check b.toSeq == @[1, 2]

  # SPEC: DS-DEQUE-05
  test "DS-DEQUE-05 Given the empty deque, when peeking or popping, then ends are none and pops stay empty":
    let d = emptyDeque[int]()
    check d.peekFront.isNone
    check d.peekBack.isNone
    check d.popFront.isEmpty
    check d.popBack.isEmpty

  # SPEC: DS-DEQUE-06
  test "DS-DEQUE-06 Given many pushes at one end, when popped from the other end, then order is preserved":
    var d = emptyDeque[int]()
    for i in 0 ..< 3000:
      d = d.pushFront(i)
    for i in 0 ..< 3000:
      check d.peekBack == some(i)
      d = d.popBack
    check d.isEmpty
