import std/[unittest, options, algorithm, sets, sequtils]
import propcheck
import nimcs/ds/bit_vector

proc sizes(): Gen[int] {.raises: [ValueError].} =
  pick([0, 1, 2, 31, 63, 64, 65, 127, 128, 130, 200])

proc indexSets(): Gen[(int, seq[int])] {.raises: [ValueError].} =
  ## A size and in-range indices (possibly repeated), built from raw ints reduced modulo the size.
  map(pair(sizes(), seqOf(intIn(0, 1000), 0, 60)),
    proc(t: (int, seq[int])): (int, seq[int]) {.raises: [].} =
      var idx: seq[int]
      if t[0] > 0:
        for x in t[1]:
          idx.add x mod t[0]
      (t[0], idx))

func model(idx: seq[int]): seq[int] =
  toHashSet(idx).toSeq.sorted

func build(size: int; idx: seq[int]): BitVector =
  fromIndices(size, idx).get

suite "bit_vector":
  # SPEC: DS-BITVECTOR-01
  test "DS-BITVECTOR-01 Given a negative size or an out-of-range index, when constructing, then none; otherwise len is the size":
    check bitVector(-1).isNone
    check fromIndices(-1, newSeq[int]()).isNone
    check fromIndices(5, [5]).isNone
    check fromIndices(5, [-1]).isNone
    let z = bitVector(70).get
    check z.len == 70 and z.count == 0 and z.invariantsHold
    check bitVector(0).get.len == 0

  # SPEC: DS-BITVECTOR-02
  test "DS-BITVECTOR-02 Given a size and indices, when testing every position, then exactly the given indices are set":
    let outcome = check(indexSets(),
      proc(t: (int, seq[int])): bool {.raises: [CatchableError].} =
        let v = build(t[0], t[1])
        for i in 0 ..< t[0]:
          if v.test(i) != (i in t[1]): return false
        not v.test(-1) and not v.test(t[0]) and v.toIndices == model(t[1]) and v.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BITVECTOR-03
  test "DS-BITVECTOR-03 Given any vector, when setting or clearing a bit twice, then the second result equals the first":
    let outcome = check(pair(indexSets(), intIn(0, 199)),
      proc(t: ((int, seq[int]), int)): bool {.raises: [CatchableError].} =
        let ((size, idx), i) = t
        let v = build(size, idx)
        if i >= size: return v.withBit(i).isNone and v.withoutBit(i).isNone
        let a = v.withBit(i).get
        let b = v.withoutBit(i).get
        a.withBit(i).get == a and b.withoutBit(i).get == b and a.test(i) and not b.test(i) and
          a.withoutBit(i).get == b and a.invariantsHold and b.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BITVECTOR-04
  test "DS-BITVECTOR-04 Given a vector, when setting or clearing a bit, then the old vector is unchanged":
    let v = fromIndices(10, [1, 3]).get
    let a = v.withBit(5).get
    let b = v.withoutBit(1).get
    check v.toIndices == @[1, 3]
    check a.toIndices == @[1, 3, 5]
    check b.toIndices == @[3]

  # SPEC: DS-BITVECTOR-05
  test "DS-BITVECTOR-05 Given any vector, when counting, then count is the number of distinct indices":
    let outcome = check(indexSets(),
      proc(t: (int, seq[int])): bool {.raises: [CatchableError].} =
        build(t[0], t[1]).count == model(t[1]).len)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BITVECTOR-06
  test "DS-BITVECTOR-06 Given any vector, when asking rank at every position, then it is the number of members below it":
    let outcome = check(indexSets(),
      proc(t: (int, seq[int])): bool {.raises: [CatchableError].} =
        let v = build(t[0], t[1])
        let members = model(t[1])
        for i in 0 .. t[0]:
          var below = 0
          for m in members:
            if m < i: inc below
          if v.rank(i) != some(below): return false
        v.rank(-1).isNone and v.rank(t[0] + 1).isNone and v.rank(t[0]) == some(members.len))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BITVECTOR-07
  test "DS-BITVECTOR-07 Given any vector, when selecting the k-th member, then it is the k-th smallest index and rank inverts it":
    let outcome = check(indexSets(),
      proc(t: (int, seq[int])): bool {.raises: [CatchableError].} =
        let v = build(t[0], t[1])
        let members = model(t[1])
        for k in 0 ..< members.len:
          if v.select(k) != some(members[k]): return false
          if v.rank(members[k]) != some(k): return false
        v.select(members.len).isNone and v.select(-1).isNone)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BITVECTOR-08
  test "DS-BITVECTOR-08 Given vectors of one size, when combining, then union, intersection and difference match the set operations":
    let outcome = check(pair(sizes(), pair(seqOf(intIn(0, 1000), 0, 50), seqOf(intIn(0, 1000), 0, 50))),
      proc(t: (int, (seq[int], seq[int]))): bool {.raises: [CatchableError].} =
        let size = t[0]
        var xs, ys: seq[int]
        if size > 0:
          for x in t[1][0]: xs.add x mod size
          for y in t[1][1]: ys.add y mod size
        let a = build(size, xs)
        let b = build(size, ys)
        let sa = toHashSet(xs)
        let sb = toHashSet(ys)
        a.union(b).get.toIndices == (sa + sb).toSeq.sorted and
          a.intersection(b).get.toIndices == (sa * sb).toSeq.sorted and
          a.difference(b).get.toIndices == (sa - sb).toSeq.sorted)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BITVECTOR-09
  test "DS-BITVECTOR-09 Given vectors, when taking union or intersection, then each is commutative, associative and idempotent":
    let outcome = check(pair(indexSets(), pair(seqOf(intIn(0, 1000), 0, 30), seqOf(intIn(0, 1000), 0, 30))),
      proc(t: ((int, seq[int]), (seq[int], seq[int]))): bool {.raises: [CatchableError].} =
        let size = t[0][0]
        var ys, zs: seq[int]
        if size > 0:
          for y in t[1][0]: ys.add y mod size
          for z in t[1][1]: zs.add z mod size
        let a = build(size, t[0][1])
        let b = build(size, ys)
        let c = build(size, zs)
        a.union(b) == b.union(a) and a.intersection(b) == b.intersection(a) and
          a.union(b).get.union(c) == a.union(b.union(c).get) and
          a.intersection(b).get.intersection(c) == a.intersection(b.intersection(c).get) and
          a.union(a).get == a and a.intersection(a).get == a)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BITVECTOR-10
  test "DS-BITVECTOR-10 Given a vector, when complementing, then it flips exactly the bits below len and twice gives the original":
    let outcome = check(indexSets(),
      proc(t: (int, seq[int])): bool {.raises: [CatchableError].} =
        let v = build(t[0], t[1])
        let c = v.complement
        c.complement == v and c.count == t[0] - v.count and c.invariantsHold and
          c.union(v).get.count == t[0] and c.intersection(v).get.count == 0)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BITVECTOR-11
  test "DS-BITVECTOR-11 Given vectors of different sizes, when combining, then the result is none":
    let a = bitVector(10).get
    let b = bitVector(11).get
    check a.union(b).isNone
    check a.intersection(b).isNone
    check a.difference(b).isNone
    check a.union(a).isSome

  # SPEC: DS-BITVECTOR-12
  test "DS-BITVECTOR-12 Given sizes at word boundaries, when setting the last bit, then no bit past the end appears":
    for size in [1, 63, 64, 65, 128]:
      let v = bitVector(size).get.withBit(size - 1).get
      check v.invariantsHold
      check v.count == 1
      check v.complement.count == size - 1
      check v.toIndices == @[size - 1]
