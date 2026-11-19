import std/[unittest, options, algorithm, sets, tables, sequtils]
import propcheck
import nimcs/ds/rb_tree

proc keys(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-40, 40), 0, 60)

suite "rb_tree":
  # SPEC: DS-RBTREE-01
  test "DS-RBTREE-01 Given any keys, when inserted into a set, then toSeq is the sorted distinct keys":
    let outcome = check(keys(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let s = fromSeq(xs)
        s.toSeq == xs.toHashSet.toSeq.sorted and s.len == xs.toHashSet.len)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-RBTREE-02
  test "DS-RBTREE-02 Given pairs, when put into a map, then get returns the last value of each key and none otherwise":
    let outcome = check(pair(keys(), intIn(0, 3)),
      proc(a: (seq[int], int)): bool {.raises: [CatchableError].} =
        var pairs: seq[(int, int)]
        var model = initTable[int, int]()
        for i, k in a[0]:
          pairs.add (k, i)
          model[k] = i
        let m = fromPairs(pairs)
        for k in -41 .. 41:
          if m.get(k) != (if k in model: some(model[k]) else: none(int)): return false
          if m.contains(k) != (k in model): return false
        m.len == model.len)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-RBTREE-03
  test "DS-RBTREE-03 Given any insertion order, when the tree is built, then the red-black invariants hold after every insert":
    let outcome = check(keys(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        var s = emptySet[int]()
        for x in xs:
          s = s.incl(x)
          if not s.invariantsHold: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-RBTREE-04
  test "DS-RBTREE-04 Given sorted input, when inserted, then the height stays logarithmic":
    var m = emptyMap[int, int]()
    for i in 1 .. 1023:
      m = m.put(i, i)
    check m.invariantsHold
    check m.height <= 20   # 2 * log2(1024)

  # SPEC: DS-RBTREE-05
  test "DS-RBTREE-05 Given a map, when putting a key, then the old map is unchanged":
    let m = fromPairs([(1, 10), (2, 20)])
    let m2 = m.put(2, 99).put(3, 30)
    check m.toSeq == @[(1, 10), (2, 20)]
    check m2.toSeq == @[(1, 10), (2, 99), (3, 30)]
    check m.len == 2
    check m2.len == 3

  # SPEC: DS-RBTREE-06
  test "DS-RBTREE-06 Given the empty map, when looking up, then get is none and the map is empty":
    let m = emptyMap[string, int]()
    check m.get("a").isNone
    check m.toSeq.len == 0
    check m.len == 0
    check m.invariantsHold

  # SPEC: DS-RBTREE-07
  test "DS-RBTREE-07 Given a set, when including a present key, then the set is equal in content and size":
    let outcome = check(keys(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let s = fromSeq(xs)
        for x in xs:
          if s.incl(x).toSeq != s.toSeq or s.incl(x).len != s.len: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-RBTREE-08
  test "DS-RBTREE-08 Given a tree where a grandchild breaks the search order, when checking invariants, then they do not hold":
    # root 5, left 3, 3's right child 7: locally ordered (7 > 3) but 7 sits left of 5
    let none0 = emptyMap[int, int]()
    let n7 = graft(cRed, 7, 0, none0, none0)
    let n3 = graft(cBlack, 3, 0, none0, n7)
    let n8 = graft(cBlack, 8, 0, none0, none0)
    let bad = graft(cBlack, 5, 0, n3, n8)
    check bad.len == 4
    check bad.get(7).isNone          # the lookup really is broken
    check not bad.invariantsHold

  # SPEC: DS-RBTREE-08
  test "DS-RBTREE-08 Given a hand-built valid tree, when checking invariants, then they hold":
    let none0 = emptyMap[int, int]()
    let good = graft(cBlack, 2, 0, graft(cRed, 1, 0, none0, none0), graft(cRed, 3, 0, none0, none0))
    check good.invariantsHold
    check good.get(3).isSome
    let redRed = graft(cBlack, 3, 0, graft(cRed, 2, 0, graft(cRed, 1, 0, none0, none0), none0), none0)
    check not redRed.invariantsHold                                   # a red node with a red child
    check not graft(cBlack, 2, 0, graft(cBlack, 1, 0, none0, none0), none0).invariantsHold  # unequal black heights
    check not graft(cRed, 1, 0, none0, none0).invariantsHold          # a red root
