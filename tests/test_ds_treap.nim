import std/[unittest, options, algorithm, sets, sequtils]
import propcheck
import nimcs/fp/result
import nimcs/ds/treap

proc keys(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-25, 25), 0, 60)

func dedupSorted(xs: seq[int]): seq[int] =
  xs.toHashSet.toSeq.sorted

suite "treap":
  # SPEC: DS-TREAP-01
  test "DS-TREAP-01 Given any keys, when inserted, then contains agrees with a set and toSeq is the sorted distinct keys":
    let outcome = check(keys(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let t = fromSeq(7'u64, xs)
        let ref1 = dedupSorted(xs)
        t.toSeq == ref1 and t.len == ref1.len and
          toSeq(-30 .. 30).allIt(t.contains(it) == (it in ref1)))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-TREAP-02
  test "DS-TREAP-02 Given a treap, when inserting a present key or deleting an absent one, then nothing changes":
    let outcome = check(keys(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let t = fromSeq(3'u64, xs)
        t.insert(100).insert(100).preorder == t.insert(100).preorder and
          t.delete(999).preorder == t.preorder and
          xs.allIt(t.insert(it).preorder == t.preorder) and
          xs.allIt(t.delete(it).delete(it).preorder == t.delete(it).preorder))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-TREAP-03
  test "DS-TREAP-03 Given a treap, when deleting a key, then it is gone and the others stay":
    let outcome = check(pair(keys(), intIn(-25, 25)),
      proc(t: (seq[int], int)): bool {.raises: [CatchableError].} =
        let tr = fromSeq(1'u64, t[0])
        let d = tr.delete(t[1])
        d.toSeq == dedupSorted(t[0]).filterIt(it != t[1]) and not d.contains(t[1]) and d.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-TREAP-04
  test "DS-TREAP-04 Given two insertion orders of the same keys and one seed, when comparing, then the shapes are identical":
    let outcome = check(keys(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let a = fromSeq(42'u64, xs)
        let b = fromSeq(42'u64, xs.reversed)
        let c = fromSeq(42'u64, xs.sorted)
        a.preorder == b.preorder and a.preorder == c.preorder and
          a.preorder == fromSeq(42'u64, dedupSorted(xs)).preorder)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-TREAP-05
  test "DS-TREAP-05 Given the same keys and different seeds, when comparing, then the contents agree though the shapes may differ":
    let ks = toSeq(1 .. 40)
    let a = fromSeq(1'u64, ks)
    let b = fromSeq(2'u64, ks)
    check a.toSeq == b.toSeq
    check a.preorder != b.preorder
    check a.seed == 1'u64 and b.seed == 2'u64

  # SPEC: DS-TREAP-06
  test "DS-TREAP-06 Given a treap and a key, when splitting, then the parts hold the smaller and larger keys and found tells presence":
    let outcome = check(pair(keys(), intIn(-30, 30)),
      proc(t: (seq[int], int)): bool {.raises: [CatchableError].} =
        let tr = fromSeq(5'u64, t[0])
        let s = tr.split(t[1])
        let all = dedupSorted(t[0])
        s.less.toSeq == all.filterIt(it < t[1]) and s.greater.toSeq == all.filterIt(it > t[1]) and
          s.found == (t[1] in all) and s.less.invariantsHold and s.greater.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-TREAP-07
  test "DS-TREAP-07 Given the two halves of a split, when merged, then the original key set is back":
    let outcome = check(pair(keys(), intIn(-30, 30)),
      proc(t: (seq[int], int)): bool {.raises: [CatchableError].} =
        let tr = fromSeq(5'u64, t[0])
        let s = tr.split(t[1])
        let m = s.less.merge(s.greater)
        let whole = if s.found: tr.delete(t[1]) else: tr
        m.isOk and m.value.preorder == whole.preorder and m.value.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-TREAP-08
  test "DS-TREAP-08 Given overlapping key ranges or different seeds, when merging, then an error is returned":
    let a = fromSeq(1'u64, [1, 2, 3])
    let b = fromSeq(1'u64, [3, 4])
    let c = fromSeq(2'u64, [10, 11])
    check a.merge(b) == err(Treap[int], keysOverlap)
    check a.merge(c) == err(Treap[int], seedMismatch)
    check a.merge(fromSeq(1'u64, [4, 5])).isOk
    check emptyTreap[int](1).merge(a).isOk

  # SPEC: DS-TREAP-09
  test "DS-TREAP-09 Given a treap, when inserting or deleting, then the old version is unchanged":
    let t = fromSeq(9'u64, [5, 1, 9])
    let a = t.insert(7)
    let b = t.delete(5)
    check t.toSeq == @[1, 5, 9]
    check a.toSeq == @[1, 5, 7, 9]
    check b.toSeq == @[1, 9]

  # SPEC: DS-TREAP-10
  test "DS-TREAP-10 Given random inserts and deletes, when checking the structure, then its invariants hold at every step":
    let outcome = check(seqOf(intIn(0, 9), 0, 80),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        var t = emptyTreap[int](11)
        for op in ops:
          t = if op < 6: t.insert(op * 7 mod 13) else: t.delete(op * 5 mod 13)
          if not t.invariantsHold: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-TREAP-11
  test "DS-TREAP-11 Given the empty treap, when asking min, max, contains or deleting, then it answers none, false and stays empty":
    let t = emptyTreap[int]()
    check t.isEmpty and t.len == 0 and t.height == 0
    check t.minKey.isNone and t.maxKey.isNone
    check not t.contains(1)
    check t.delete(1).isEmpty
    check fromSeq(1'u64, [4, 2, 8]).minKey == some(2)
    check fromSeq(1'u64, [4, 2, 8]).maxKey == some(8)

  # SPEC: DS-TREAP-12
  test "DS-TREAP-12 Given ascending keys inserted in order, when measuring the height, then it stays logarithmic rather than linear":
    let n = 20_000
    let t = fromSeq(123'u64, toSeq(1 .. n))
    check t.len == n
    check t.invariantsHold
    check t.height < 60        # log2(20000) is about 14.3; a chain would be 20000

  # SPEC: DS-TREAP-13
  test "DS-TREAP-13 Given string keys, when inserted, then they come out sorted and the shape does not depend on the insertion order":
    let t = fromSeq(0'u64, ["pear", "apple", "fig", "apple"])
    check t.toSeq == @["apple", "fig", "pear"]
    check t.preorder == fromSeq(0'u64, ["fig", "pear", "apple"]).preorder
