import std/[unittest, options, algorithm, sequtils, math]
import propcheck
import nimcs/ds/avl_tree

proc ints(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-20, 20), 0, 60)

suite "avl_tree":
  # SPEC: DS-AVLTREE-01
  test "DS-AVLTREE-01 Given any items, when inserted, then toSeq is the sorted distinct items and the AVL invariant holds":
    let outcome = check(ints(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let t = fromSeq(xs)
        t.toSeq == xs.sorted.deduplicate(isSorted = true) and t.len == t.toSeq.len and
          t.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-AVLTREE-02
  test "DS-AVLTREE-02 Given any items, when asking contains, then it is true exactly for the inserted items":
    let outcome = check(pair(ints(), intIn(-25, 25)),
      proc(t: (seq[int], int)): bool {.raises: [CatchableError].} =
        fromSeq(t[0]).contains(t[1]) == (t[1] in t[0]))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-AVLTREE-03
  test "DS-AVLTREE-03 Given random inserts and deletes, when checking the structure, then the balance invariant holds at every step":
    let outcome = check(seqOf(intIn(0, 39), 0, 120),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        var t = emptyAvl[int]()
        for op in ops:
          t = if op < 25: t.insert(op * 7 mod 31) else: t.delete(op mod 31)
          if not t.invariantsHold: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-AVLTREE-04
  test "DS-AVLTREE-04 Given any items and one of them, when deleting it, then it is gone and the rest remain":
    let outcome = check(pair(ints(), intIn(-25, 25)),
      proc(t: (seq[int], int)): bool {.raises: [CatchableError].} =
        let tree = fromSeq(t[0])
        let d = tree.delete(t[1])
        d.toSeq == tree.toSeq.filterIt(it != t[1]) and not d.contains(t[1]) and d.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-AVLTREE-05
  test "DS-AVLTREE-05 Given sorted inserts, when measuring the height, then it stays logarithmic where a plain BST would be a list":
    let t = fromSeq((1 .. 1023).toSeq)
    check t.len == 1023
    check t.height <= int(1.4405 * log2(1025.0))
    check t.height >= 10
    check t.invariantsHold
    let down = fromSeq((1 .. 1000).toSeq.reversed)
    check down.height <= int(1.4405 * log2(1002.0))

  # SPEC: DS-AVLTREE-06
  test "DS-AVLTREE-06 Given the four shapes that need a rotation, when inserting three items, then each ends with height 2 and sorted contents":
    check fromSeq([3, 2, 1]).height == 2           # left-left: single right rotation
    check fromSeq([1, 2, 3]).height == 2           # right-right: single left rotation
    check fromSeq([3, 1, 2]).height == 2           # left-right: double rotation
    check fromSeq([1, 3, 2]).height == 2           # right-left: double rotation
    for xs in [@[3, 2, 1], @[1, 2, 3], @[3, 1, 2], @[1, 3, 2]]:
      check fromSeq(xs).toSeq == @[1, 2, 3]
      check fromSeq(xs).invariantsHold

  # SPEC: DS-AVLTREE-07
  test "DS-AVLTREE-07 Given a tree, when inserting or deleting, then the old version is unchanged":
    let t = fromSeq([3, 1, 2])
    let a = t.insert(9)
    let b = t.delete(1)
    check t.toSeq == @[1, 2, 3]
    check a.toSeq == @[1, 2, 3, 9]
    check b.toSeq == @[2, 3]

  # SPEC: DS-AVLTREE-08
  test "DS-AVLTREE-08 Given the empty tree, when querying, then it has no smallest and delete keeps it empty":
    let e = emptyAvl[int]()
    check e.isEmpty and e.len == 0 and e.height == 0 and e.invariantsHold
    check e.smallest.isNone
    check e.delete(1).isEmpty
    check fromSeq([4, 9, 1]).smallest == some(1)
    check fromSeq([4, 9]).insert(4).len == 2
