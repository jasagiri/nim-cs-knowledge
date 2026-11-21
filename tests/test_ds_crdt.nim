import std/[unittest, options, algorithm]
import propcheck
import nimcs/ds/crdt

func rid(i: int): ReplicaId =
  let r = replicaId(["a", "b", "c"][i])
  doAssert r.isOk
  r.value

# --- helpers that state the laws once, for every type --------------------------------------------

func commutes[T](s: seq[T]): bool =
  s[0].merge(s[1]) == s[1].merge(s[0])

func associates[T](s: seq[T]): bool =
  s[0].merge(s[1]).merge(s[2]) == s[0].merge(s[1].merge(s[2]))

func idempotent[T](s: seq[T]): bool =
  s[0].merge(s[0]) == s[0] and s[0].merge(s[1]).merge(s[1]) == s[0].merge(s[1]) and
    s[0].merge(s[1]).merge(s[0]) == s[0].merge(s[1])

func inOrder[T](states: seq[T]; keys: seq[int]): seq[T] =
  ## The states sorted by key (ties by position): a permutation chosen by the generated keys.
  var idx: seq[int]
  for i in 0 ..< states.len: idx.add i
  idx.sort(proc(x, y: int): int = (if keys[x] != keys[y]: cmp(keys[x], keys[y]) else: cmp(x, y)))
  for i in idx: result.add states[i]

func foldLeft[T](states: seq[T]): T =
  result = states[0]
  for i in 1 ..< states.len: result = result.merge(states[i])

func foldRight[T](states: seq[T]): T =
  result = states[states.len - 1]
  for i in countdown(states.len - 2, 0): result = states[i].merge(result)

func orderFree[T](states: seq[T]; keys: seq[int]): bool =
  let expected = foldLeft(states)
  foldLeft(inOrder(states, keys)) == expected and foldRight(inOrder(states, keys)) == expected

# --- generators of states -------------------------------------------------------------------------

type Op = (int, int, int)          # replica, kind or stamp, amount or value

proc opGen(kinds, amounts: int): Gen[Op] {.raises: [ValueError].} =
  map(pair(intIn(0, 2), pair(intIn(0, kinds - 1), intIn(0, amounts))),
    proc(t: (int, (int, int))): Op {.raises: [].} = (t[0], t[1][0], t[1][1]))

func gcFrom(ops: seq[Op]): GCounter =
  result = emptyGCounter()
  for o in ops: result = result.increment(rid(o[0]), o[2])

func pnFrom(ops: seq[Op]): PNCounter =
  result = emptyPNCounter()
  for o in ops:
    result = if o[1] == 0: result.increment(rid(o[0]), o[2]) else: result.decrement(rid(o[0]), o[2])

func lwwFrom(ops: seq[Op]): LwwRegister[int] =
  result = emptyRegister[int]()
  for o in ops: result = result.write(o[1], rid(o[0]), o[2])

func orFrom(ops: seq[Op]): OrSet[int] =
  result = emptyOrSet[int]()
  for o in ops:
    result = if o[1] == 0: result.add(rid(o[0]), o[2]) else: result.remove(o[2])

proc gcGen(): Gen[GCounter] {.raises: [ValueError].} =
  map(seqOf(opGen(1, 4), 0, 10), gcFrom)
proc pnGen(): Gen[PNCounter] {.raises: [ValueError].} =
  map(seqOf(opGen(2, 4), 0, 10), pnFrom)
proc lwwGen(): Gen[LwwRegister[int]] {.raises: [ValueError].} =
  map(seqOf(opGen(6, 3), 0, 4), lwwFrom)
proc orGen(): Gen[OrSet[int]] {.raises: [ValueError].} =
  map(seqOf(opGen(2, 4), 0, 12), orFrom)

template threeStates(gen: untyped; T: typedesc; prop: untyped) =
  let outcome = check(seqOf(gen, 3, 3),
    proc(s {.inject.}: seq[T]): bool {.raises: [CatchableError].} = prop)
  checkpoint describe(outcome)
  check outcome.passed

template manyStates(gen: untyped; T: typedesc) =
  let outcome = check(pair(seqOf(gen, 1, 6), seqOf(intIn(0, 50), 6, 6)),
    proc(a: (seq[T], seq[int])): bool {.raises: [CatchableError].} = orderFree(a[0], a[1]))
  checkpoint describe(outcome)
  check outcome.passed

suite "crdt":
  # SPEC: DS-CRDT-01
  test "DS-CRDT-01 Given an empty name, when making a replica id, then it is refused":
    check replicaId("") == err(ReplicaId, ceEmptyReplica)
    check replicaId("a").isOk
    check $replicaId("r1").value == "r1"

  # SPEC: DS-CRDT-02
  test "DS-CRDT-02 Given counters that each replica changed on its own copy, when merged, then the value is the total of all increments and each replica keeps its own count":
    let outcome = check(seqOf(opGen(1, 4), 0, 20),
      proc(ops: seq[Op]): bool {.raises: [CatchableError].} =
        var copies = [emptyGCounter(), emptyGCounter(), emptyGCounter()]
        var total = 0
        var per = [0, 0, 0]
        for o in ops:
          copies[o[0]] = copies[o[0]].increment(rid(o[0]), o[2])
          total += o[2]
          per[o[0]] += o[2]
        let merged = copies[1].merge(copies[2]).merge(copies[0])
        if merged.value != total: return false
        for i in 0 .. 2:
          if merged.countOf(rid(i)) != per[i]: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-CRDT-03
  test "DS-CRDT-03 Given any two G-Counters, when merged either way round, then the results are equal":
    threeStates(gcGen(), GCounter, commutes(s))

  # SPEC: DS-CRDT-04
  test "DS-CRDT-04 Given any three G-Counters, when merged in either grouping, then the results are equal":
    threeStates(gcGen(), GCounter, associates(s))

  # SPEC: DS-CRDT-05
  test "DS-CRDT-05 Given any G-Counters, when merging a state again, then nothing changes":
    threeStates(gcGen(), GCounter, idempotent(s))

  # SPEC: DS-CRDT-06
  test "DS-CRDT-06 Given several G-Counters, when merged in any order and grouping, then the result is the same":
    manyStates(gcGen(), GCounter)

  # SPEC: DS-CRDT-07
  test "DS-CRDT-07 Given a G-Counter, when merging or incrementing, then the value never goes down":
    let outcome = check(seqOf(gcGen(), 2, 2),
      proc(s: seq[GCounter]): bool {.raises: [CatchableError].} =
        let m = s[0].merge(s[1])
        m.value >= s[0].value and m.value >= s[1].value and
          s[0].increment(rid(0), 3).value == s[0].value + 3 and s[0].increment(rid(1), 0) == s[0])
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-CRDT-08
  test "DS-CRDT-08 Given PN-Counters changed on separate copies, when merged, then the value is all increments minus all decrements":
    let outcome = check(seqOf(opGen(2, 4), 0, 20),
      proc(ops: seq[Op]): bool {.raises: [CatchableError].} =
        var copies = [emptyPNCounter(), emptyPNCounter(), emptyPNCounter()]
        var total = 0
        for o in ops:
          if o[1] == 0:
            copies[o[0]] = copies[o[0]].increment(rid(o[0]), o[2])
            total += o[2]
          else:
            copies[o[0]] = copies[o[0]].decrement(rid(o[0]), o[2])
            total -= o[2]
        copies[2].merge(copies[0]).merge(copies[1]).value == total)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-CRDT-09
  test "DS-CRDT-09 Given any two PN-Counters, when merged either way round, then the results are equal":
    threeStates(pnGen(), PNCounter, commutes(s))

  # SPEC: DS-CRDT-10
  test "DS-CRDT-10 Given any three PN-Counters, when merged in either grouping, then the results are equal":
    threeStates(pnGen(), PNCounter, associates(s))

  # SPEC: DS-CRDT-11
  test "DS-CRDT-11 Given any PN-Counters, when merging a state again, then nothing changes":
    threeStates(pnGen(), PNCounter, idempotent(s))

  # SPEC: DS-CRDT-12
  test "DS-CRDT-12 Given several PN-Counters, when merged in any order and grouping, then the result is the same":
    manyStates(pnGen(), PNCounter)

  # SPEC: DS-CRDT-13
  test "DS-CRDT-13 Given writes, when merged, then the winner is the one with the largest stamp, then replica id, then value, and an empty register loses":
    let outcome = check(seqOf(opGen(6, 3), 1, 8),
      proc(ops: seq[Op]): bool {.raises: [CatchableError].} =
        var best = ops[0]
        for o in ops:
          if (o[1], o[0], o[2]) > (best[1], best[0], best[2]): best = o
        var parts: seq[LwwRegister[int]]
        for o in ops: parts.add registerOf(o[1], rid(o[0]), o[2])
        let merged = foldLeft(parts)
        merged.value == some(best[2]) and merged.stamp == some(best[1]) and merged.writer == some(rid(best[0])))
    checkpoint describe(outcome)
    check outcome.passed
    let empty = emptyRegister[string]()
    check empty.value.isNone
    check empty.merge(empty) == empty
    let w = registerOf(5, rid(0), "x")
    check empty.merge(w) == w and w.merge(empty) == w
    # a tie on the stamp goes to the larger replica id, whichever side it is merged from
    let tie1 = registerOf(7, rid(0), "from a")
    let tie2 = registerOf(7, rid(1), "from b")
    check tie1.merge(tie2).value == some("from b") and tie2.merge(tie1).value == some("from b")
    # an older write does not replace a newer one
    check registerOf(9, rid(0), "new").write(3, rid(2), "old").value == some("new")

  # SPEC: DS-CRDT-14
  test "DS-CRDT-14 Given any two LWW-Registers, when merged either way round, then the results are equal":
    threeStates(lwwGen(), LwwRegister[int], commutes(s))

  # SPEC: DS-CRDT-15
  test "DS-CRDT-15 Given any three LWW-Registers, when merged in either grouping, then the results are equal":
    threeStates(lwwGen(), LwwRegister[int], associates(s))

  # SPEC: DS-CRDT-16
  test "DS-CRDT-16 Given any LWW-Registers, when merging a state again, then nothing changes":
    threeStates(lwwGen(), LwwRegister[int], idempotent(s))

  # SPEC: DS-CRDT-17
  test "DS-CRDT-17 Given several LWW-Registers, when merged in any order and grouping, then the result is the same":
    manyStates(lwwGen(), LwwRegister[int])

  # SPEC: DS-CRDT-18
  test "DS-CRDT-18 Given an OR-Set, when adding and removing, then remove cancels only the additions it has seen and a concurrent add wins":
    let empty = emptyOrSet[string]()
    let a1 = empty.add(rid(0), "x")
    check "x" in a1 and a1.len == 1
    check a1.remove("x").len == 0 and "x" notin a1.remove("x")
    check "x" in a1                                  # the old value is unchanged
    check empty.remove("x") == empty                 # removing a non-member changes nothing
    # replica a adds x, both copies sync, then a removes x while b adds x again
    let b1 = a1                                      # b's copy after the sync
    let aRemoved = a1.remove("x")
    let bAdded = b1.add(rid(1), "x")
    check "x" in aRemoved.merge(bAdded)              # the concurrent add wins
    check "x" in bAdded.merge(aRemoved)
    # without the concurrent add the removal wins on both sides
    check "x" notin aRemoved.merge(b1) and "x" notin b1.merge(aRemoved)
    # an element can be added again after its removal
    let again = aRemoved.add(rid(0), "x")
    check "x" in again and again.tombstoneCount == 1
    check again.merge(aRemoved) == again

  # SPEC: DS-CRDT-19
  test "DS-CRDT-19 Given one replica's adds and removes, when compared with a set model, then the elements agree at every step":
    let outcome = check(seqOf(opGen(2, 5), 0, 30),
      proc(ops: seq[Op]): bool {.raises: [CatchableError].} =
        var s = emptyOrSet[int]()
        var model: seq[int]
        for o in ops:
          if o[1] == 0:
            s = s.add(rid(0), o[2])
            if o[2] notin model: model.add o[2]
          else:
            s = s.remove(o[2])
            let at = model.find(o[2])
            if at >= 0: model.delete(at)
          model.sort()
          if s.elements != model or s.len != model.len: return false
          for m in model:
            if m notin s: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-CRDT-20
  test "DS-CRDT-20 Given any two OR-Sets, when merged either way round, then the results are equal":
    threeStates(orGen(), OrSet[int], commutes(s))

  # SPEC: DS-CRDT-21
  test "DS-CRDT-21 Given any three OR-Sets, when merged in either grouping, then the results are equal":
    threeStates(orGen(), OrSet[int], associates(s))

  # SPEC: DS-CRDT-22
  test "DS-CRDT-22 Given any OR-Sets, when merging a state again, then nothing changes":
    threeStates(orGen(), OrSet[int], idempotent(s))

  # SPEC: DS-CRDT-23
  test "DS-CRDT-23 Given several OR-Sets, when merged in any order and grouping, then the result is the same":
    manyStates(orGen(), OrSet[int])
