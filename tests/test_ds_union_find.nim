import std/[unittest, math, bitops]
import propcheck
import nimcs/ds/union_find

proc edges(): Gen[seq[(int, int)]] {.raises: [ValueError].} =
  seqOf(pair(intIn(0, 19), intIn(0, 19)), 0, 40)

func naiveLabels(es: seq[(int, int)]): seq[int] =
  ## Reference: label propagation until no label changes.
  result = newSeq[int](20)
  for i in 0 ..< 20: result[i] = i
  var changed = true
  while changed:
    changed = false
    for (a, b) in es:
      let m = min(result[a], result[b])
      if result[a] != m or result[b] != m:
        result[a] = m
        result[b] = m
        changed = true

suite "union_find":
  # SPEC: DS-UNIONFIND-01
  test "DS-UNIONFIND-01 Given any unions, when asking same, then it agrees with a naive reference":
    let outcome = check(edges(),
      proc(es: seq[(int, int)]): bool {.raises: [CatchableError].} =
        var u = emptyUnionFind()
        for (a, b) in es: u = u.union(a, b)
        let ref0 = naiveLabels(es)
        for a in 0 ..< 20:
          for b in 0 ..< 20:
            if u.same(a, b) != (ref0[a] == ref0[b]): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-UNIONFIND-02
  test "DS-UNIONFIND-02 Given any unions, when asking same, then it is reflexive, symmetric and transitive":
    let outcome = check(edges(),
      proc(es: seq[(int, int)]): bool {.raises: [CatchableError].} =
        var u = emptyUnionFind()
        for (a, b) in es: u = u.union(a, b)
        for a in 0 ..< 20:
          if not u.same(a, a): return false
          for b in 0 ..< 20:
            if u.same(a, b) != u.same(b, a): return false
            for c in 0 ..< 20:
              if u.same(a, b) and u.same(b, c) and not u.same(a, c): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-UNIONFIND-03
  test "DS-UNIONFIND-03 Given a union, when repeated, then the relation and the component count are unchanged":
    let outcome = check(pair(edges(), pair(intIn(0, 19), intIn(0, 19))),
      proc(t: (seq[(int, int)], (int, int))): bool {.raises: [CatchableError].} =
        var u = emptyUnionFind()
        for (a, b) in t[0]: u = u.union(a, b)
        let once = u.union(t[1][0], t[1][1])
        let twice = once.union(t[1][0], t[1][1])
        if once.components != twice.components or once.len != twice.len: return false
        for a in 0 ..< 20:
          for b in 0 ..< 20:
            if once.same(a, b) != twice.same(a, b): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-UNIONFIND-04
  test "DS-UNIONFIND-04 Given a structure, when uniting, then the old version still answers as before":
    let u = emptyUnionFind().union(1, 2)
    let v = u.union(2, 3)
    check u.same(1, 2)
    check not u.same(1, 3)
    check v.same(1, 3)
    check u.components == 1
    check v.components == 1
    check emptyUnionFind().union(1, 2).union(3, 4).components == 2

  # SPEC: DS-UNIONFIND-05
  test "DS-UNIONFIND-05 Given chained unions, when measuring a root path, then union by rank keeps it within log2 of the element count":
    var u = emptyUnionFind()
    for i in 0 ..< 255:
      u = u.union(i, i + 1)
    check u.components == 1
    for x in 0 .. 255:
      check u.pathLength(x) <= int(log2(256.0))

  # SPEC: DS-UNIONFIND-06
  test "DS-UNIONFIND-06 Given a path, when compressing, then the representative is the same and the path is shorter":
    var u = emptyUnionFind()
    for i in 0 ..< 63:
      u = u.union(i, i + 1)
    for x in 0 .. 63:
      let (root, compressed) = u.findCompress(x)
      check root == u.find(x)
      check compressed.pathLength(x) <= 1
      check compressed.same(x, 0)
      check compressed.components == u.components

  # SPEC: DS-UNIONFIND-07
  test "DS-UNIONFIND-07 Given an unknown element, when finding, then it is its own set and the structure is unchanged":
    let u = emptyUnionFind()
    check u.find(42) == 42
    check u.len == 0
    check u.same(5, 5)
    check not u.same(5, 6)
    check u.add(5).add(5).len == 1

  # SPEC: DS-UNIONFIND-08
  test "DS-UNIONFIND-08 Given random unions over many elements, when measuring every root path, then it is at most floor(log2 of the element count)":
    let outcome = check(seqOf(pair(intIn(0, 99), intIn(0, 99)), 0, 150),
      proc(es: seq[(int, int)]): bool {.raises: [CatchableError].} =
        var u = emptyUnionFind()
        for (a, b) in es:
          u = u.union(a, b)
          if u.len > 0:
            for x in [a, b]:
              if u.pathLength(x) > fastLog2(u.len): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed
