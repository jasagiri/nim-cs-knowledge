import std/[unittest, options, algorithm, sequtils]
import propcheck
import nimcs/ds/bst

proc ints(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-20, 20), 0, 40)

suite "bst":
  # SPEC: DS-BST-01
  test "DS-BST-01 Given any items, when inserted, then in-order traversal is the sorted distinct items":
    let outcome = check(ints(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let t = fromSeq(xs)
        t.inOrder == xs.sorted.deduplicate(isSorted = true) and t.len == t.inOrder.len)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BST-02
  test "DS-BST-02 Given any items, when asking contains, then it is true exactly for the inserted items":
    let outcome = check(pair(ints(), intIn(-25, 25)),
      proc(t: (seq[int], int)): bool {.raises: [CatchableError].} =
        fromSeq(t[0]).contains(t[1]) == (t[1] in t[0]))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BST-03
  test "DS-BST-03 Given a tree, when inserting an item already present, then the tree is the same":
    let t = fromSeq([5, 2, 8])
    let again = t.insert(2)
    check again.len == 3
    check again.preOrder == t.preOrder

  # SPEC: DS-BST-04
  test "DS-BST-04 Given any items and one of them, when deleting it, then it is gone, the rest remain and order holds":
    let outcome = check(pair(ints(), intIn(-25, 25)),
      proc(t: (seq[int], int)): bool {.raises: [CatchableError].} =
        let tree = fromSeq(t[0])
        let d = tree.delete(t[1])
        d.inOrder == tree.inOrder.filterIt(it != t[1]) and not d.contains(t[1]) and
          d.invariantsHold and d.len == d.inOrder.len)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BST-05
  test "DS-BST-05 Given a node with two children, when deleting it, then the in-order successor takes its place":
    let t = fromSeq([5, 2, 8, 1, 3, 7, 9, 6])
    let d = t.delete(5)
    check d.preOrder == @[6, 2, 1, 3, 8, 7, 9]
    check d.invariantsHold

  # SPEC: DS-BST-06
  test "DS-BST-06 Given the tree 4 2 6 1 3 5 7, when traversing, then the three orders match the textbook lists":
    let t = fromSeq([4, 2, 6, 1, 3, 5, 7])
    check t.inOrder == @[1, 2, 3, 4, 5, 6, 7]
    check t.preOrder == @[4, 2, 1, 3, 6, 5, 7]
    check t.postOrder == @[1, 3, 2, 5, 7, 6, 4]

  # SPEC: DS-BST-07
  test "DS-BST-07 Given any items, when re-inserting the pre-order list, then the same shape is rebuilt":
    let outcome = check(ints(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let t = fromSeq(xs)
        fromSeq(t.preOrder).preOrder == t.preOrder)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BST-08
  test "DS-BST-08 Given a tree, when inserting or deleting, then the old version is unchanged":
    let t = fromSeq([3, 1, 2])
    let a = t.insert(9)
    let b = t.delete(1)
    check t.inOrder == @[1, 2, 3]
    check a.inOrder == @[1, 2, 3, 9]
    check b.inOrder == @[2, 3]

  # SPEC: DS-BST-09
  test "DS-BST-09 Given the empty tree, when querying, then smallest and largest are none and delete keeps it empty":
    let e = emptyBst[int]()
    check e.isEmpty and e.len == 0 and e.height == 0
    check e.smallest.isNone and e.largest.isNone
    check e.delete(1).isEmpty
    check e.inOrder.len == 0
    let t = fromSeq([4, 9, 1])
    check t.smallest == some(1) and t.largest == some(9)

  # SPEC: DS-BST-10
  test "DS-BST-10 Given sorted inserts, when measuring the height, then it equals the item count (the tree is a list)":
    let sortedTree = fromSeq((1 .. 500).toSeq)
    check sortedTree.height == 500
    check sortedTree.invariantsHold
    let balancedOrder = fromSeq([4, 2, 6, 1, 3, 5, 7])
    check balancedOrder.height == 3

  # SPEC: DS-BST-11
  test "DS-BST-11 Given random inserts and deletes, when checking the structure, then the order invariant holds at every step":
    let outcome = check(seqOf(intIn(0, 29), 0, 80),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        var t = emptyBst[int]()
        for op in ops:
          t = if op < 20: t.insert(op * 7 mod 13) else: t.delete(op mod 13)
          if not t.invariantsHold: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BST-12
  test "DS-BST-12 Given one million ascending items (a chain), when the tree is dropped, then nothing overflows the stack":
    block:
      var items = newSeq[int](1_000_000)
      for i in 0 ..< items.len:
        items[i] = i
      let chain = ascendingChain(items)
      check chain.isSome
      check chain.get.len == 1_000_000
      check chain.get.smallest == some(0)
      check chain.get.largest == some(999_999)
      check chain.get.contains(500_000)
      let shorter = chain.get.delete(0)       # shares 999_999 nodes with `chain`; both are dropped
      check shorter.len == 999_999
    check true

  # SPEC: DS-BST-13
  test "DS-BST-13 Given items that are not strictly ascending, when asking for a chain, then none; given ascending items, then it equals repeated insert":
    check ascendingChain([1, 1, 2]).isNone
    check ascendingChain([3, 2]).isNone
    check ascendingChain(newSeq[int]()).get.isEmpty
    let chain = ascendingChain([1, 2, 3, 4]).get
    check chain.height == 4 and chain.invariantsHold
    check chain.preOrder == fromSeq([1, 2, 3, 4]).preOrder
