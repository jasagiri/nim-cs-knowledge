import std/[unittest, options]
import propcheck
import nimcs/ds/pvector

suite "pvector":
  # SPEC: DS-PVECTOR-01
  test "DS-PVECTOR-01 Given any items, when pushed, then toSeq and get(i) return them in order":
    let outcome = check(seqOf(intIn(-50, 50), 0, 120),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let v = fromSeq(xs)
        if v.toSeq != xs or v.len != xs.len: return false
        for i, x in xs:
          if v.get(i) != some(x): return false
        v.get(-1).isNone and v.get(xs.len).isNone)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-PVECTOR-02
  test "DS-PVECTOR-02 Given a vector and an index, when updated, then only that index changes and the original is unchanged":
    let outcome = check(pair(seqOf(intIn(-50, 50), 0, 80), intIn(0, 90)),
      proc(a: (seq[int], int)): bool {.raises: [CatchableError].} =
        let v = fromSeq(a[0])
        let u = v.updated(a[1], 999)
        if a[1] >= a[0].len: return u.isNone
        var expected = a[0]
        expected[a[1]] = 999
        u.isSome and u.get.toSeq == expected and v.toSeq == a[0])
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-PVECTOR-03
  test "DS-PVECTOR-03 Given a vector, when pushing, then the old version keeps its length and contents":
    let v = fromSeq([1, 2, 3])
    let w = v.push(4)
    check v.toSeq == @[1, 2, 3]
    check w.toSeq == @[1, 2, 3, 4]

  # SPEC: DS-PVECTOR-04
  test "DS-PVECTOR-04 Given sizes around the 32-way boundaries, when pushed, then every element is reachable and depth grows by one level per factor 32":
    for n in [0, 1, 31, 32, 33, 1023, 1024, 1025, 1056, 1057, 2000, 32767, 32768, 32769]:
      var v = emptyVector[int]()
      for i in 0 ..< n: v = v.push(i)
      check v.len == n
      for i in 0 ..< n:
        check v.get(i) == some(i)
    check fromSeq(newSeq[int](32)).depth == 1
    check fromSeq(newSeq[int](33)).depth == 2
    check fromSeq(newSeq[int](1024)).depth == 2
    check fromSeq(newSeq[int](1025)).depth == 3
    check fromSeq(newSeq[int](32768)).depth == 3
    check fromSeq(newSeq[int](32769)).depth == 4

  # SPEC: DS-PVECTOR-05
  test "DS-PVECTOR-05 Given the empty vector, when reading or updating, then get and updated are none":
    let v = emptyVector[int]()
    check v.isEmpty
    check v.get(0).isNone
    check v.updated(0, 1).isNone
    check default(PVector[int]).push(7).toSeq == @[7]

  # SPEC: DS-PVECTOR-06
  test "DS-PVECTOR-06 Given a vector of 33000 elements with four trie levels, when updated at random indices, then only those indices change and the original is unchanged":
    var base: seq[int]
    for i in 0 ..< 33_000: base.add i
    let v = fromSeq(base)
    check v.depth == 4
    let outcome = check(seqOf(pair(intIn(0, 32_999), intIn(-9, 9)), 0, 40),
      proc(edits: seq[(int, int)]): bool {.raises: [CatchableError].} =
        var cur = v
        var model = base
        for (i, x) in edits:
          cur = cur.updated(i, x).get
          model[i] = x
        for (i, _) in edits:
          if cur.get(i) != some(model[i]): return false
        cur.get(0) == some(model[0]) and cur.get(32_999) == some(model[32_999]) and
          cur.len == 33_000 and v.get(32_999) == some(32_999) and
          (edits.len == 0 or v.get(edits[0][0]) == some(edits[0][0])))
    checkpoint describe(outcome)
    check outcome.passed
    check v.toSeq == base
