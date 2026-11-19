import std/[unittest, options, bitops]
import propcheck
import nimcs/ds/skew_list

proc ints(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-50, 50), 0, 60)

suite "skew_list":
  # SPEC: DS-SKEWLIST-01
  test "DS-SKEWLIST-01 Given any items, when built by consing, then toSeq returns them in order and get(i) is the i-th":
    let outcome = check(ints(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let s = fromSeq(xs)
        if s.toSeq != xs or s.len != xs.len: return false
        for i, x in xs:
          if s.get(i) != some(x): return false
        s.get(-1).isNone and s.get(xs.len).isNone)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SKEWLIST-02
  test "DS-SKEWLIST-02 Given any list, when consing then taking the tail, then head and tail round-trip":
    let outcome = check(pair(ints(), intIn(-9, 9)),
      proc(a: (seq[int], int)): bool {.raises: [CatchableError].} =
        let s = fromSeq(a[0])
        let t = s.cons(a[1])
        t.head == some(a[1]) and t.tail.toSeq == a[0] and t.tail.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SKEWLIST-03
  test "DS-SKEWLIST-03 Given any list and index, when updated, then only that index changes and the original is unchanged":
    let outcome = check(pair(ints(), intIn(0, 80)),
      proc(a: (seq[int], int)): bool {.raises: [CatchableError].} =
        let s = fromSeq(a[0])
        let u = s.updated(a[1], 999)
        if a[1] >= a[0].len: return u.isNone
        var expected = a[0]
        expected[a[1]] = 999
        u.isSome and u.get.toSeq == expected and s.toSeq == a[0] and u.get.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SKEWLIST-04
  test "DS-SKEWLIST-04 Given any sequence of cons and tail, when running, then the skew-binary invariants hold and the spine stays short":
    let outcome = check(seqOf(intIn(0, 9), 0, 100),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        var s = emptySkew[int]()
        for op in ops:
          s = if op < 6: s.cons(op) else: s.tail
          if not s.invariantsHold: return false
          if s.weights.len > 2 * fastLog2(s.len + 1) + 1: return false   # at most 2 floor(log2(n+1)) + 1 trees
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SKEWLIST-05
  test "DS-SKEWLIST-05 Given the empty list, when asking head, tail or get, then head and get are none and tail is empty":
    let s = emptySkew[int]()
    check s.head.isNone
    check s.tail.isEmpty
    check s.get(0).isNone
    check s.updated(0, 1).isNone

  # SPEC: DS-SKEWLIST-06
  test "DS-SKEWLIST-06 Given 1000 items, when looking up every index, then each lookup finds its element":
    var xs: seq[int]
    for i in 0 ..< 1000: xs.add i * 3
    let s = fromSeq(xs)
    check s.invariantsHold
    for i in 0 ..< 1000:
      check s.get(i) == some(i * 3)
