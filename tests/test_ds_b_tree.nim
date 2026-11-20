import std/[unittest, options, algorithm, sequtils]
import propcheck
import nimcs/ds/b_tree

proc keysGen(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-40, 40), 0, 80)

func sortedDistinct(xs: seq[int]): seq[int] =
  xs.sorted.deduplicate(isSorted = true)

suite "b_tree":
  # SPEC: DS-BTREE-01
  test "DS-BTREE-01 Given a degree below 2, when creating a tree, then none; otherwise an empty tree of that degree":
    check newBTree[int](1).isNone
    check newBTree[int](-3).isNone
    check fromSeq(0, [1, 2]).isNone
    let t = newBTree[int](3).get
    check t.isEmpty
    check t.len == 0
    check t.minDegree == 3
    check t.height == 0
    check t.toSortedSeq.len == 0
    check not t.contains(1)

  # SPEC: DS-BTREE-02
  test "DS-BTREE-02 Given any keys and a degree, when inserted, then iteration is the sorted distinct keys":
    let outcome = check(pair(intIn(2, 5), keysGen()),
      proc(t: (int, seq[int])): bool {.raises: [CatchableError].} =
        let tree = fromSeq(t[0], t[1]).get
        tree.toSortedSeq == sortedDistinct(t[1]) and tree.len == sortedDistinct(t[1]).len and
          sequtils.toSeq(tree.items) == tree.toSortedSeq)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BTREE-03
  test "DS-BTREE-03 Given a tree, when asking contains, then it is true exactly for the inserted keys":
    let outcome = check(pair(keysGen(), intIn(-45, 45)),
      proc(t: (seq[int], int)): bool {.raises: [CatchableError].} =
        fromSeq(2, t[0]).get.contains(t[1]) == (t[1] in t[0]))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BTREE-04
  test "DS-BTREE-04 Given random inserts, when checking the structure, then node sizes, child counts and leaf depth hold at every step":
    let outcome = check(pair(intIn(2, 4), keysGen()),
      proc(t: (int, seq[int])): bool {.raises: [CatchableError].} =
        var tree = newBTree[int](t[0]).get
        for x in t[1]:
          tree = tree.insert(x)
          if not tree.invariantsHold: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BTREE-05
  test "DS-BTREE-05 Given a member, when inserting it again, then the result equals the tree and shares its size":
    let outcome = check(pair(intIn(2, 4), keysGen()),
      proc(t: (int, seq[int])): bool {.raises: [CatchableError].} =
        let tree = fromSeq(t[0], t[1]).get
        for x in t[1]:
          let again = tree.insert(x)
          if again.toSortedSeq != tree.toSortedSeq or again.len != tree.len: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BTREE-06
  test "DS-BTREE-06 Given a tree, when inserting a new key, then the old version is unchanged":
    let base = fromSeq(2, [4, 2, 6, 1, 3, 5, 7]).get
    let more = base.insert(0).insert(8)
    check base.toSortedSeq == @[1, 2, 3, 4, 5, 6, 7]
    check not base.contains(0)
    check more.toSortedSeq == @[0, 1, 2, 3, 4, 5, 6, 7, 8]
    check base.invariantsHold and more.invariantsHold

  # SPEC: DS-BTREE-07
  test "DS-BTREE-07 Given ascending and descending inserts, when counting levels, then the height stays logarithmic":
    var asc = newBTree[int](16).get
    var desc = newBTree[int](16).get
    for i in 1 .. 20_000:
      asc = asc.insert(i)
      desc = desc.insert(-i)
    check asc.len == 20_000 and desc.len == 20_000
    check asc.invariantsHold and desc.invariantsHold
    # at degree 16 every non-root node has at least 15 keys, so 20 000 keys need at most 4 levels
    check asc.height <= 4 and desc.height <= 4
    check asc.toSortedSeq == sequtils.toSeq(1 .. 20_000)

  # SPEC: DS-BTREE-08
  test "DS-BTREE-08 Given n keys and degree t, when reading the height h, then n is at least 2 * t^(h-1) - 1":
    let outcome = check(pair(intIn(2, 5), keysGen()),
      proc(t: (int, seq[int])): bool {.raises: [CatchableError].} =
        let tree = fromSeq(t[0], t[1]).get
        if tree.isEmpty: return tree.height == 0
        var least = 2
        for _ in 2 .. tree.height:
          least *= t[0]
        tree.len >= least - 1)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BTREE-09
  test "DS-BTREE-09 Given a key type ordered only by `<`, when inserting equivalent keys, then one stays":
    let t = fromSeq(2, ["b", "a", "b", "c", "a"]).get
    check t.toSortedSeq == @["a", "b", "c"]
