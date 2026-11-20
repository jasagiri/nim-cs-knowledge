import std/[unittest, options, algorithm]
import propcheck
import nimcs/ds/linked_list

suite "linked_list":
  # SPEC: DS-LINKEDLIST-01
  test "DS-LINKEDLIST-01 Given any items, when pushed at the back, then forward is the input order and backward is its reverse":
    let outcome = check(seqOf(intIn(-20, 20), 0, 40),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        var l = emptyList[int]()
        for x in xs:
          l = l.pushBack(x).list
        l.toSeqForward == xs and l.toSeqBackward == xs.reversed and l.len == xs.len and
          l.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-LINKEDLIST-02
  test "DS-LINKEDLIST-02 Given any items, when pushed at the front, then forward is the reverse of the input order":
    let outcome = check(seqOf(intIn(-20, 20), 0, 40),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        var l = emptyList[int]()
        for x in xs:
          l = l.pushFront(x).list
        l.toSeqForward == xs.reversed and l.toSeqBackward == xs and l.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-LINKEDLIST-03
  test "DS-LINKEDLIST-03 Given a handle, when inserting after it, then the new element sits right after it":
    let a = emptyList[string]().pushBack("a")
    let b = a.list.pushBack("c")
    let mid = b.list.insertAfter(a.id, "b")
    check mid.isSome
    check mid.get.list.toSeqForward == @["a", "b", "c"]
    check mid.get.list.toSeqBackward == @["c", "b", "a"]
    check mid.get.list.get(mid.get.id) == some("b")
    let tail = mid.get.list.insertAfter(b.id, "d")
    check tail.get.list.toSeqForward == @["a", "b", "c", "d"]
    check tail.get.list.invariantsHold

  # SPEC: DS-LINKEDLIST-04
  test "DS-LINKEDLIST-04 Given a handle, when removing it, then the element is gone from both directions and the list stays consistent":
    let a = emptyList[int]().pushBack(1)
    let b = a.list.pushBack(2)
    let c = b.list.pushBack(3)
    for (victim, expected) in [(a.id, @[2, 3]), (b.id, @[1, 3]), (c.id, @[1, 2])]:
      let r = c.list.remove(victim)
      check r.isSome
      check r.get.toSeqForward == expected
      check r.get.toSeqBackward == expected.reversed
      check r.get.invariantsHold
      check r.get.get(victim).isNone

  # SPEC: DS-LINKEDLIST-05
  test "DS-LINKEDLIST-05 Given a removed element whose slot was reused, when using the old handle, then it is rejected":
    let a = emptyList[string]().pushBack("old")
    let gone = a.list.remove(a.id).get
    let reused = gone.pushBack("new")
    check reused.id.index == a.id.index          # the freed slot was reused
    check reused.list.get(a.id).isNone           # the stale handle does not see "new"
    check reused.list.remove(a.id).isNone
    check reused.list.insertAfter(a.id, "x").isNone
    check reused.list.get(reused.id) == some("new")

  # SPEC: DS-LINKEDLIST-06
  test "DS-LINKEDLIST-06 Given a list, when updating, then the old version is unchanged":
    let a = emptyList[int]().pushBack(1)
    let b = a.list.pushBack(2)
    let removed = b.list.remove(a.id).get
    let grown = b.list.pushFront(0).list
    check b.list.toSeqForward == @[1, 2]
    check removed.toSeqForward == @[2]
    check grown.toSeqForward == @[0, 1, 2]

  # SPEC: DS-LINKEDLIST-07
  test "DS-LINKEDLIST-07 Given random pushes, inserts and removals, when checking the structure, then the invariants hold at every step":
    let outcome = check(seqOf(intIn(0, 29), 0, 100),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        var l = emptyList[int]()
        var ids: seq[NodeId]
        for op in ops:
          if op < 8:
            let r = l.pushBack(op)
            l = r.list
            ids.add r.id
          elif op < 14:
            let r = l.pushFront(op)
            l = r.list
            ids.add r.id
          elif op < 22 and ids.len > 0:
            let r = l.insertAfter(ids[op mod ids.len], op)
            if r.isSome:
              l = r.get.list
              ids.add r.get.id
          elif ids.len > 0:
            let r = l.remove(ids[op mod ids.len])
            if r.isSome: l = r.get
          if not l.invariantsHold: return false
          if l.toSeqForward.reversed != l.toSeqBackward: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-LINKEDLIST-08
  test "DS-LINKEDLIST-08 Given the empty list, when reading, then it is empty and a handle that is out of range is rejected":
    let e = emptyList[int]()
    check e.isEmpty and e.len == 0 and e.invariantsHold
    check e.toSeqForward.len == 0 and e.toSeqBackward.len == 0
    let other = emptyList[int]().pushBack(7)
    check e.get(other.id).isNone
    check e.remove(other.id).isNone
    check e.get(NodeId(index: -1, generation: 0)).isNone
