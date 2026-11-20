import std/[unittest, options]
import propcheck
import nimcs/ds/fenwick_tree
import nimcs/ds/segment_tree

proc arrays(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-50, 50), 0, 60)

func naiveSum(xs: seq[int]; l, r: int): int =
  for i in l ..< r:
    result += xs[i]

func prefixesAgree(f: FenwickTree; xs: seq[int]): bool =
  for r in 0 .. xs.len:
    if f.prefixSum(r) != some(naiveSum(xs, 0, r)): return false
  true

suite "fenwick_tree":
  # SPEC: DS-FENWICK-01
  test "DS-FENWICK-01 Given any array, when asking every prefix sum, then it equals the sum of that prefix":
    let outcome = check(arrays(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let f = fromSeq(xs)
        for r in 0 .. xs.len:
          if f.prefixSum(r) != some(naiveSum(xs, 0, r)): return false
        f.len == xs.len)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-FENWICK-02
  test "DS-FENWICK-02 Given any array and range, when asking rangeSum, then it equals the sum of the slice":
    let outcome = check(pair(arrays(), pair(intIn(0, 65), intIn(0, 65))),
      proc(t: (seq[int], (int, int))): bool {.raises: [CatchableError].} =
        let (l, r) = t[1]
        let f = fromSeq(t[0])
        if l > r or r > t[0].len: return f.rangeSum(l, r).isNone
        f.rangeSum(l, r) == some(naiveSum(t[0], l, r)))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-FENWICK-03
  test "DS-FENWICK-03 Given random point updates, when compared with a plain array, then every prefix sum and element agrees":
    let outcome = check(pair(arrays(), seqOf(pair(intIn(0, 59), intIn(-20, 20)), 0, 30)),
      proc(t: (seq[int], seq[(int, int)])): bool {.raises: [CatchableError].} =
        var model = t[0]
        var f = fromSeq(t[0])
        for (i, d) in t[1]:
          let next = f.add(i, d)
          if i >= model.len:
            if next.isSome: return false
          else:
            model[i] += d
            f = next.get
        f.values == model and prefixesAgree(f, model))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-FENWICK-04
  test "DS-FENWICK-04 Given a tree, when updating, then the old tree is unchanged":
    let f = fromSeq([1, 2, 3, 4])
    let g = f.add(1, 10).get
    check f.values == @[1, 2, 3, 4]
    check g.values == @[1, 12, 3, 4]
    check f.prefixSum(4) == some(10)
    check g.prefixSum(4) == some(20)

  # SPEC: DS-FENWICK-05
  test "DS-FENWICK-05 Given a list of updates, when applied with addAll or one by one, then the trees agree":
    let outcome = check(pair(arrays(), seqOf(pair(intIn(0, 59), intIn(-20, 20)), 0, 30)),
      proc(t: (seq[int], seq[(int, int)])): bool {.raises: [CatchableError].} =
        let f = fromSeq(t[0])
        var stepwise = some(f)
        for u in t[1]:
          stepwise = if stepwise.isNone: stepwise else: stepwise.get.add(u[0], u[1])
        let batch = f.addAll(t[1])
        batch.isSome == stepwise.isSome and (batch.isNone or batch.get.values == stepwise.get.values))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-FENWICK-06
  test "DS-FENWICK-06 Given indices or sizes out of range, when using the tree, then the result is none":
    check zeros(-1).isNone
    let f = zeros(3).get
    check f.len == 3
    check f.values == @[0, 0, 0]
    check f.add(3, 1).isNone
    check f.add(-1, 1).isNone
    check f.prefixSum(4).isNone
    check f.prefixSum(-1).isNone
    check f.get(3).isNone
    check f.addAll([(0, 1), (3, 1)]).isNone
    check fromSeq(newSeq[int]()).prefixSum(0) == some(0)

  # SPEC: DS-FENWICK-07
  test "DS-FENWICK-07 Given the same array, when queried through a Fenwick tree and a segment tree, then all range sums agree":
    let sumM = initMonoid(0, proc(a, b: int): int = a + b)
    let outcome = check(pair(arrays(), pair(intIn(0, 60), intIn(0, 60))),
      proc(t: (seq[int], (int, int))): bool {.raises: [CatchableError].} =
        let (l, r) = t[1]
        fromSeq(t[0]).rangeSum(l, r) == sumM.fromSeq(t[0]).query(l, r))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-FENWICK-08
  test "DS-FENWICK-08 Given an array, when rebuilt from its values, then the tree answers the same queries":
    let outcome = check(arrays(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let f = fromSeq(xs)
        fromSeq(f.values).values == xs and fromSeq(f.values).prefixSum(xs.len) == f.prefixSum(xs.len))
    checkpoint describe(outcome)
    check outcome.passed
