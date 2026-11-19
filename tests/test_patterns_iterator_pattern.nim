import std/[unittest, algorithm, sequtils, options]
import propcheck
import nimcs/patterns/iterator_pattern

func sortedUnique(xs: seq[int]): seq[int] {.raises: [].} =
  result = xs.sorted
  result = result.deduplicate(isSorted = true)

func drain(c: Cursor): seq[int] {.raises: [].} =
  var cur = c
  while true:
    let n = cur.next
    if n.isNone: break
    result.add n.get[0]
    cur = n.get[1]

func ints(): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(-20, 20), 0, 25)

# SPEC: GOF-ITER-01
test "GOF-ITER-01 Given any inserted values, when iterated with items, then they come ascending without repeats":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    var seen: seq[int]
    for x in fromSeq(xs).items: seen.add x
    seen == sortedUnique(xs))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-ITER-02
test "GOF-ITER-02 Given any tree, when a cursor is drained, then it yields exactly what items yields":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let t = fromSeq(xs)
    drain(cursor(t)) == toSeq(t))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-ITER-03
test "GOF-ITER-03 Given a cursor, when next is called twice on the same cursor, then both calls agree (cursors are values)":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let c = cursor(fromSeq(xs))
    let a = c.next
    let b = c.next
    a.isSome == b.isSome and (a.isNone or (a.get[0] == b.get[0] and drain(a.get[1]) == drain(b.get[1]))))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-ITER-04
test "GOF-ITER-04 Given a tree, when iterated twice, then both traversals are the same":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let t = fromSeq(xs)
    toSeq(t) == toSeq(t))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-ITER-05
test "GOF-ITER-05 Given two trees, when merged by cursors, then the result is the ascending union without repeats":
  let outcome = check(pair(ints(), ints()), proc(p: (seq[int], seq[int])): bool {.raises: [CatchableError].} =
    mergeUnion(fromSeq(p[0]), fromSeq(p[1])) == sortedUnique(p[0] & p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-ITER-06
test "GOF-ITER-06 Given a tree, when a value is inserted, then the old tree is unchanged":
  let outcome = check(pair(ints(), intIn(-30, 30)), proc(p: (seq[int], int)): bool {.raises: [CatchableError].} =
    let t = fromSeq(p[0])
    let before = toSeq(t)
    let t2 = t.insert(p[1])
    toSeq(t) == before and toSeq(t2) == sortedUnique(p[0] & @[p[1]]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-ITER-07
test "GOF-ITER-07 Given an empty tree, when iterated, then nothing is yielded and the cursor ends":
  let t = fromSeq(newSeq[int]())
  check toSeq(t).len == 0
  check cursor(t).next.isNone
  check mergeUnion(t, t).len == 0
