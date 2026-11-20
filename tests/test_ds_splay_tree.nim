import std/[unittest, options, algorithm, sets, sequtils]
import propcheck
import nimcs/ds/splay_tree

proc keys(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-25, 25), 0, 60)

func dedupSorted(xs: seq[int]): seq[int] =
  xs.toHashSet.toSeq.sorted

suite "splay_tree":
  # SPEC: DS-SPLAYTREE-01
  test "DS-SPLAYTREE-01 Given any keys, when inserted, then toSeq is the sorted distinct keys and lookup finds exactly those":
    let outcome = check(keys(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let t = fromSeq(xs)
        let all = dedupSorted(xs)
        t.toSeq == all and t.len == all.len and
          toSeq(-30 .. 30).allIt(t.lookup(it).found == (it in all) and t.contains(it) == (it in all)))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SPLAYTREE-02
  test "DS-SPLAYTREE-02 Given a tree and a present key, when looking it up, then the returned tree has that key at the root":
    let outcome = check(pair(keys(), intIn(-25, 25)),
      proc(t: (seq[int], int)): bool {.raises: [CatchableError].} =
        let tr = fromSeq(t[0])
        let r = tr.lookup(t[1])
        r.tree.toSeq == tr.toSeq and r.tree.invariantsHold and
          (not r.found or r.tree.rootKey == some(t[1])))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SPLAYTREE-03
  test "DS-SPLAYTREE-03 Given an absent key, when looking it up, then found is false and the last node visited is at the root":
    let t = fromSeq([10, 20, 30, 40])
    let r = t.lookup(25)
    check not r.found
    check r.tree.rootKey.get in [20, 30]
    check r.tree.toSeq == @[10, 20, 30, 40]
    check emptyTree[int]().lookup(1).found == false

  # SPEC: DS-SPLAYTREE-04
  test "DS-SPLAYTREE-04 Given a tree, when inserting a key, then it is at the root and a present key leaves the key set unchanged":
    let outcome = check(pair(keys(), intIn(-25, 25)),
      proc(t: (seq[int], int)): bool {.raises: [CatchableError].} =
        let tr = fromSeq(t[0])
        let a = tr.insert(t[1])
        a.rootKey == some(t[1]) and a.toSeq == dedupSorted(t[0] & @[t[1]]) and
          a.len == a.toSeq.len and a.insert(t[1]).toSeq == a.toSeq and a.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SPLAYTREE-05
  test "DS-SPLAYTREE-05 Given a tree, when deleting a key, then it is gone, the rest stays, and an absent key changes nothing":
    let outcome = check(pair(keys(), intIn(-25, 25)),
      proc(t: (seq[int], int)): bool {.raises: [CatchableError].} =
        let tr = fromSeq(t[0])
        let d = tr.delete(t[1])
        d.toSeq == dedupSorted(t[0]).filterIt(it != t[1]) and d.len == d.toSeq.len and
          d.invariantsHold and d.delete(t[1]).toSeq == d.toSeq)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SPLAYTREE-06
  test "DS-SPLAYTREE-06 Given a tree, when looking up, inserting or deleting, then the old version is unchanged":
    let t = fromSeq([5, 1, 9, 3])
    let before = t.toSeq
    let rootBefore = t.rootKey
    check t.lookup(9).tree.rootKey == some(9)
    check t.insert(7).len == 5
    check t.delete(5).len == 3
    check t.toSeq == before
    check t.rootKey == rootBefore
    check t.len == 4

  # SPEC: DS-SPLAYTREE-07
  test "DS-SPLAYTREE-07 Given a lookup, when the same key is asked again on the returned tree, then it is at depth 0":
    let t = fromSeq(toSeq(1 .. 200))
    check t.depthOf(1).get == 199           # ascending inserts leave the smallest key deepest
    let once = t.lookup(1)
    check once.found
    check once.tree.depthOf(1) == some(0)
    check once.tree.lookup(1).tree.depthOf(1) == some(0)

  # SPEC: DS-SPLAYTREE-08
  test "DS-SPLAYTREE-08 Given one old version, when its deepest key is looked up repeatedly without threading the tree, then every lookup is as deep as the first":
    let t = fromSeq(toSeq(1 .. 200))
    for _ in 1 .. 5:
      let r = t.lookup(1)
      check r.found
      check t.depthOf(1).get == 199         # the old version never improved
    var threaded = t
    var depths: seq[int]
    for _ in 1 .. 3:
      threaded = threaded.lookup(1).tree
      depths.add threaded.depthOf(1).get
    check depths == @[0, 0, 0]

  # SPEC: DS-SPLAYTREE-09
  test "DS-SPLAYTREE-09 Given a long run of lookups threaded forward, when the keys are random, then every tree stays valid and the key set never changes":
    let outcome = check(pair(keys(), seqOf(intIn(-25, 25), 0, 60)),
      proc(t: (seq[int], seq[int])): bool {.raises: [CatchableError].} =
        var tr = fromSeq(t[0])
        let all = tr.toSeq
        for k in t[1]:
          let r = tr.lookup(k)
          tr = r.tree
          if r.found != (k in all) or not tr.invariantsHold or tr.toSeq != all: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SPLAYTREE-10
  test "DS-SPLAYTREE-10 Given the empty tree, when asking anything, then it is empty and deleting leaves it empty":
    let t = emptyTree[int]()
    check t.isEmpty and t.len == 0
    check t.rootKey.isNone
    check t.depthOf(1).isNone
    check not t.contains(1)
    check t.delete(1).isEmpty
    check t.toSeq.len == 0

  # SPEC: DS-SPLAYTREE-11
  test "DS-SPLAYTREE-11 Given a thousand ascending inserts, when everything is looked up in order, then the work stays far below quadratic":
    var t = fromSeq(toSeq(1 .. 1000))
    var total = 0
    for k in 1 .. 1000:
      total += t.depthOf(k).get
      t = t.lookup(k).tree
    check t.invariantsHold
    check total < 8000                     # about 5 per key; a degenerate tree would cost about 500000

  # SPEC: DS-SPLAYTREE-12
  test "DS-SPLAYTREE-12 Given a chain of one million nodes from ascending inserts, when it is used and dropped, then nothing overflows the stack":
    block:
      var t = emptyTree[int]()
      for i in 1 .. 1_000_000:
        t = t.insert(i)
      check t.len == 1_000_000
      check t.rootKey == some(1_000_000)
      check t.depthOf(1) == some(999_999)
      check t.contains(1)
    check true
