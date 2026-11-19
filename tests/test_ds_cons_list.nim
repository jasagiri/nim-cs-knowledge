import std/[unittest, options, sequtils, algorithm]
import propcheck
import nimcs/ds/cons_list

proc ints(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-50, 50), 0, 30)

suite "cons_list":
  # SPEC: DS-CONSLIST-01
  test "DS-CONSLIST-01 Given any list, when consing x, then head is x and tail is the original":
    let outcome = check(pair(ints(), intIn(-9, 9)),
      proc(a: (seq[int], int)): bool {.raises: [CatchableError].} =
        let xs = fromSeq(a[0])
        let ys = xs.cons(a[1])
        ys.head == some(a[1]) and ys.tail == xs and ys.tail.sharesNode(xs))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-CONSLIST-02
  test "DS-CONSLIST-02 Given the empty list, when asking head and tail, then head is none and tail is empty":
    let e = emptyList[int]()
    check e.isEmpty
    check e.head.isNone
    check e.tail.isEmpty
    check e.len == 0

  # SPEC: DS-CONSLIST-03
  test "DS-CONSLIST-03 Given any list, when reversed twice, then it equals the original":
    let outcome = check(ints(),
      proc(a: seq[int]): bool {.raises: [CatchableError].} =
        let xs = fromSeq(a)
        xs.reverse.reverse == xs and xs.reverse.toSeq == @(a).reversed)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-CONSLIST-04
  test "DS-CONSLIST-04 Given lists a, b, c, when appending, then append is associative with the empty list as identity":
    let outcome = check(pair(ints(), pair(ints(), ints())),
      proc(t: (seq[int], (seq[int], seq[int]))): bool {.raises: [CatchableError].} =
        let a = fromSeq(t[0])
        let b = fromSeq(t[1][0])
        let c = fromSeq(t[1][1])
        a.append(b).append(c) == a.append(b.append(c)) and
          a.append(emptyList[int]()) == a and emptyList[int]().append(a) == a and
          a.append(b).toSeq == t[0] & t[1][0])
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-CONSLIST-05
  test "DS-CONSLIST-05 Given a list, when appending b, then the result shares all of b":
    let a = fromSeq([1, 2])
    let b = fromSeq([3, 4])
    let c = a.append(b)
    check c.tail.tail.sharesNode(b)

  # SPEC: DS-CONSLIST-06
  test "DS-CONSLIST-06 Given a list, when updating a copy by cons, then the old list is unchanged":
    let xs = fromSeq([1, 2, 3])
    let ys = xs.cons(0)
    let zs = xs.cons(9)
    check xs.toSeq == @[1, 2, 3]
    check ys.toSeq == @[0, 1, 2, 3]
    check zs.toSeq == @[9, 1, 2, 3]

  # SPEC: DS-CONSLIST-07
  test "DS-CONSLIST-07 Given any list, when folding or mapping, then results agree with the seq versions":
    let outcome = check(ints(),
      proc(a: seq[int]): bool {.raises: [CatchableError].} =
        let xs = fromSeq(a)
        var total = 0
        for x in a: total += x
        xs.foldLeft(0, proc(acc, x: int): int = acc + x) == total and
          xs.map(proc(x: int): int = x * 2).toSeq == a.mapIt(it * 2) and
          xs.len == a.len)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-CONSLIST-08
  test "DS-CONSLIST-08 Given a list of three million nodes, when it goes out of scope, then dropping it does not overflow the stack":
    block:
      var xs = emptyList[int]()
      for i in 0 ..< 3_000_000:
        xs = xs.cons(i)
      check xs.len == 3_000_000
    block:
      # a shared long tail is freed only when its last owner goes
      var base = emptyList[int]()
      for i in 0 ..< 1_000_000:
        base = base.cons(i)
      let a = base.cons(-1)
      base = emptyList[int]()
      check a.len == 1_000_001

  # SPEC: DS-CONSLIST-09
  test "DS-CONSLIST-09 Given a list, when another list is consed onto it, then its first cell counts as shared":
    let a = fromSeq([1, 2])
    check a.isUnshared
    let b = a.cons(0)
    check not a.isUnshared
    check b.isUnshared
    check emptyList[int]().isUnshared
