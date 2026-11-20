import std/[unittest, options, math]
import propcheck
import nimcs/ds/sparse_table
import nimcs/ds/segment_tree

let minOp: Op[int] = proc(a, b: int): int = min(a, b)
let maxOp: Op[int] = proc(a, b: int): int = max(a, b)
let gcdOp: Op[int] = proc(a, b: int): int = gcd(a, b)
let sumOp: Op[int] = proc(a, b: int): int = a + b
let firstOp: Op[int] = proc(a, b: int): int = a      # idempotent, associative, not commutative

proc arrays(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(0, 60), 0, 70)

func naive(xs: seq[int]; l, r: int; op: Op[int]): int =
  ## Fold over xs[l ..< r], l < r.
  result = xs[l]
  for i in l + 1 ..< r:
    result = op(result, xs[i])

suite "sparse_table":
  # SPEC: DS-SPARSETABLE-01
  test "DS-SPARSETABLE-01 Given any array and range, when querying min, max, gcd or keep-left, then it equals the fold over the slice":
    for op in [minOp, maxOp, gcdOp, firstOp]:
      let outcome = check(pair(arrays(), pair(intIn(0, 75), intIn(0, 75))),
        proc(t: (seq[int], (int, int))): bool {.raises: [CatchableError].} =
          let (l, r) = t[1]
          let table = fromSeq(t[0], op)
          if l >= r or r > t[0].len: return true
          table.query(l, r) == some(naive(t[0], l, r, op)))
      checkpoint describe(outcome)
      check outcome.passed

  # SPEC: DS-SPARSETABLE-02
  test "DS-SPARSETABLE-02 Given an empty or out-of-range range, when querying, then the result is none":
    let table = fromSeq([4, 2, 7], minOp)
    check table.query(1, 1).isNone
    check table.query(2, 1).isNone
    check table.query(-1, 2).isNone
    check table.query(0, 4).isNone
    check fromSeq(newSeq[int](), minOp).query(0, 0).isNone
    check table.get(3).isNone and table.get(-1).isNone
    check table.get(1) == some(2)

  # SPEC: DS-SPARSETABLE-03
  test "DS-SPARSETABLE-03 Given n elements, when building, then there are floor(log2 n) + 1 levels":
    check fromSeq(newSeq[int](), minOp).levelCount == 0
    for n in 1 .. 70:
      let table = fromSeq(newSeq[int](n), minOp)
      var expected = 1
      while (1 shl expected) <= n: inc expected
      check table.levelCount == expected
      check table.len == n

  # SPEC: DS-SPARSETABLE-04
  test "DS-SPARSETABLE-04 Given a non-idempotent operation, when the two windows overlap, then the answer is wrong":
    let table = fromSeq([1, 1, 1], sumOp)
    check table.query(0, 1) == some(2)       # both windows are element 0: 1 + 1, not 1
    check table.query(0, 2) == some(4)       # both windows are [0,2): 2 + 2, not 2
    check table.query(0, 3) == some(4)       # windows [0,2) and [1,3) overlap: 4, not 3
    check not idempotentOn(sumOp, [1, 2, 3])
    check idempotentOn(minOp, [1, 2, 3])
    check idempotentOn(maxOp, [1, 2, 3])
    check idempotentOn(gcdOp, [0, 1, 12, 18])
    check idempotentOn(firstOp, [1, 2, 3])
    check idempotentOn(sumOp, [0])           # a finite check can refute idempotence, not prove it

  # SPEC: DS-SPARSETABLE-05
  test "DS-SPARSETABLE-05 Given the same array, when queried through a sparse table and a segment tree, then all range minima agree":
    let minM = initMonoid(high(int), proc(a, b: int): int = min(a, b))
    let outcome = check(pair(arrays(), pair(intIn(0, 75), intIn(0, 75))),
      proc(t: (seq[int], (int, int))): bool {.raises: [CatchableError].} =
        let (l, r) = t[1]
        if l >= r: return true
        fromSeq(t[0], minOp).query(l, r) == minM.fromSeq(t[0]).query(l, r))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SPARSETABLE-06
  test "DS-SPARSETABLE-06 Given a table, when querying the same range repeatedly, then the answer never changes":
    let table = fromSeq([5, 3, 8, 1, 9, 2], minOp)
    let first = table.query(1, 5)
    check first == some(1)
    check table.query(1, 5) == first
    check table.query(1, 5) == first

  # SPEC: DS-SPARSETABLE-07
  test "DS-SPARSETABLE-07 Given five thousand elements, when querying many ranges, then every answer equals the fold":
    var xs: seq[int]
    var state = 12345
    for _ in 0 ..< 5000:
      state = (state * 1103515245 + 12345) mod 2147483648
      xs.add state mod 1000
    let table = fromSeq(xs, maxOp)
    for step in 0 ..< 300:
      let l = (step * 37) mod 4900
      let r = l + 1 + (step * 91) mod (5000 - l)
      check table.query(l, r) == some(naive(xs, l, r, maxOp))
