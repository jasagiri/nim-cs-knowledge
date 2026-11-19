import std/[unittest, options]
import propcheck
import nimcs/ds/segment_tree

let sumM = initMonoid(0, proc(a, b: int): int = a + b)
let minM = initMonoid(high(int), proc(a, b: int): int = min(a, b))
let catM = initMonoid("", proc(a, b: string): string = a & b)   # associative, not commutative

func slice[T](xs: seq[T]; l, r: int): seq[T] =
  xs[l ..< r]

suite "segment_tree":
  # SPEC: DS-SEGTREE-01
  test "DS-SEGTREE-01 Given any array and range, when querying a sum, then it equals the sum of that slice":
    let outcome = check(pair(seqOf(intIn(-20, 20), 0, 50), pair(intIn(0, 55), intIn(0, 55))),
      proc(t: (seq[int], (int, int))): bool {.raises: [CatchableError].} =
        let tree = sumM.fromSeq(t[0])
        let (l, r) = t[1]
        if l > r or r > t[0].len: return tree.query(l, r).isNone
        var expected = 0
        for x in t[0].slice(l, r): expected += x
        tree.query(l, r) == some(expected))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SEGTREE-02
  test "DS-SEGTREE-02 Given a non-commutative monoid, when querying a range, then elements are combined in index order":
    let outcome = check(pair(seqOf(stringOf("xyz", 0, 3), 1, 30), pair(intIn(0, 30), intIn(0, 30))),
      proc(t: (seq[string], (int, int))): bool {.raises: [CatchableError].} =
        let tree = catM.fromSeq(t[0])
        let (l, r) = t[1]
        if l > r or r > t[0].len: return true
        var expected = ""
        for s in t[0].slice(l, r): expected &= s
        tree.query(l, r) == some(expected))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SEGTREE-03
  test "DS-SEGTREE-03 Given a tree and an index, when updating, then queries see the new value and the old tree is unchanged":
    let outcome = check(pair(seqOf(intIn(-20, 20), 1, 40), pair(intIn(0, 39), intIn(-99, 99))),
      proc(t: (seq[int], (int, int))): bool {.raises: [CatchableError].} =
        let tree = minM.fromSeq(t[0])
        let (i, x) = t[1]
        let u = tree.updated(i, x)
        if i >= t[0].len: return u.isNone
        var expected = t[0]
        expected[i] = x
        let fresh = minM.fromSeq(expected)
        for l in 0 .. expected.len:
          for r in l .. expected.len:
            if u.get.query(l, r) != fresh.query(l, r): return false
            if tree.query(l, r) != minM.fromSeq(t[0]).query(l, r): return false
        u.get.get(i) == some(x) and tree.get(i) == some(t[0][i]))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SEGTREE-04
  test "DS-SEGTREE-04 Given an empty range, when querying, then the monoid identity is returned; invalid ranges give none":
    let tree = sumM.fromSeq([1, 2, 3])
    check tree.query(2, 2) == some(0)
    check tree.query(3, 3) == some(0)
    check tree.query(-1, 2).isNone
    check tree.query(1, 4).isNone
    check tree.query(2, 1).isNone

  # SPEC: DS-SEGTREE-05
  test "DS-SEGTREE-05 Given the empty array, when building and asking, then total is the identity and every access is none or empty":
    let tree = sumM.fromSeq(newSeq[int]())
    check tree.len == 0
    check tree.total == 0
    check tree.query(0, 0) == some(0)
    check tree.get(0).isNone
    check tree.updated(0, 1).isNone

  # SPEC: DS-SEGTREE-06
  test "DS-SEGTREE-06 Given any array, when asking total, then it equals the query over the whole range":
    let outcome = check(seqOf(intIn(-20, 20), 0, 60),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let tree = sumM.fromSeq(xs)
        some(tree.total) == tree.query(0, xs.len))
    checkpoint describe(outcome)
    check outcome.passed
