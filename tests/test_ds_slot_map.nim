import std/[unittest, options]
import propcheck
import nimcs/ds/slot_map

# A model of the map: the handles ever issued, and the live ones with their values.
type
  Model = object
    map: SlotMap[int]
    issued: seq[Handle]
    live: seq[tuple[h: Handle, v: int]]
    inserts, removes: int

func modelValue(md: Model; h: Handle): Option[int] =
  for e in md.live:
    if e.h == h: return some(e.v)
  none(int)

func dropLive(live: seq[tuple[h: Handle, v: int]]; h: Handle): seq[tuple[h: Handle, v: int]] =
  for e in live:
    if not (e.h == h): result.add e

func step(md: Model; op: int): Model =
  ## Ops 0..9 insert, 10..17 remove an issued handle (maybe stale), 18..29 put on one.
  result = md
  if op < 10 or md.issued.len == 0:
    let r = result.map.insert(op)
    result.map = r.map
    result.issued.add r.handle
    result.live.add (h: r.handle, v: op)
    inc result.inserts
  elif op < 18:
    let h = md.issued[op mod md.issued.len]
    let r = result.map.remove(h)
    result.map = r.map
    if r.removed.isSome:
      result.live = result.live.dropLive(h)
      inc result.removes
  else:
    let h = md.issued[op mod md.issued.len]
    let r = result.map.put(h, op)
    result.map = r.map
    if r.ok:
      result.live = result.live.dropLive(h)
      result.live.add (h: h, v: op)

func play(ops: seq[int]): Model =
  result.map = emptySlotMap[int]()
  for op in ops:
    result = result.step(op)

func opsGen(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(0, 29), 0, 120)

func pairsOf[T](m: SlotMap[T]): seq[tuple[handle: Handle, value: T]] =
  for h, v in m.pairs: result.add (handle: h, value: v)

func samePairs(a, b: seq[tuple[handle: Handle, value: int]]): bool =
  if a.len != b.len: return false
  for i in 0 ..< a.len:
    if not (a[i].handle == b[i].handle) or a[i].value != b[i].value: return false
  true

proc allocsOfPuts(n, k: int): AllocStats =
  ## Allocations of `k` puts on a map of `n` live values whose last use is the put.
  var m = emptySlotMap[int]()
  var hs: seq[Handle]
  for i in 0 ..< n:
    let r = m.insert(i)
    m = r.map
    hs.add r.handle
  let before = getAllocStats()
  for j in 0 ..< k:
    let r = m.put(hs[j mod n], j)
    m = r.map
  result = getAllocStats() - before
  doAssert m.len == n

proc allocsOfPutsKeepingOld(n, k: int): AllocStats =
  ## The same puts when the caller still reads the map it passed in.
  var m = emptySlotMap[int]()
  var hs: seq[Handle]
  for i in 0 ..< n:
    let r = m.insert(i)
    m = r.map
    hs.add r.handle
  let before = getAllocStats()
  for j in 0 ..< k:
    let old = m
    let r = old.put(hs[j mod n], j)
    m = r.map
    doAssert old.len == m.len
  result = getAllocStats() - before

proc allocsOfReuse(n, k: int): tuple[removing, inserting: AllocStats] =
  ## Allocations of removing `k` values and then inserting `k` into the freed slots.
  var m = emptySlotMap[int]()
  var hs: seq[Handle]
  for i in 0 ..< n:
    let r = m.insert(i)
    m = r.map
    hs.add r.handle
  let b1 = getAllocStats()
  for j in 0 ..< k:
    let r = m.remove(hs[j])
    m = r.map
  result.removing = getAllocStats() - b1
  let b2 = getAllocStats()
  for j in 0 ..< k:
    let r = m.insert(j)
    m = r.map
  result.inserting = getAllocStats() - b2
  doAssert m.len == n

suite "slot_map":
  # SPEC: DS-SLOTMAP-01
  test "DS-SLOTMAP-01 Given the empty map or the zero value, when reading or inserting, then it is empty, every handle is rejected and an insert works":
    var zero: SlotMap[int]                       # the zero value is the empty map
    check zero == emptySlotMap[int]() and zero.invariantsHold
    let firstIn = zero.insert(5)
    check firstIn.map.get(firstIn.handle).get == 5 and firstIn.map.invariantsHold
    zero = default(SlotMap[int])
    check zero.isEmpty
    let e = emptySlotMap[int]()
    check e.isEmpty and e.len == 0 and e.invariantsHold
    check pairsOf(e).len == 0
    let other = emptySlotMap[int]().insert(7)
    check e.get(other.handle).isNone
    check not e.contains(other.handle)
    check e.remove(other.handle).removed.isNone
    check not e.put(other.handle, 1).ok
    check e.get(Handle(index: -1, generation: 0)).isNone
    check e.get(Handle(index: 0, generation: -1)).isNone

  # SPEC: DS-SLOTMAP-02
  test "DS-SLOTMAP-02 Given any values, when inserted, then each handle returns its value and the others are unchanged":
    let outcome = check(seqOf(intIn(-20, 20), 0, 40),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        var m = emptySlotMap[int]()
        var hs: seq[Handle]
        for x in xs:
          let r = m.insert(x)
          m = r.map
          hs.add r.handle
          if m.get(r.handle) != some(x) or not m.contains(r.handle): return false
        for i, h in hs:
          if m.get(h) != some(xs[i]): return false
        m.len == xs.len and m.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SLOTMAP-03
  test "DS-SLOTMAP-03 Given any inserts and removes, when two handles are live, then they are never equal":
    let outcome = check(opsGen(),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        var md = Model(map: emptySlotMap[int]())
        for op in ops:
          md = md.step(op)
          let hs = pairsOf(md.map)
          for i in 0 ..< hs.len:
            for j in i + 1 ..< hs.len:
              if hs[i].handle == hs[j].handle: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SLOTMAP-04
  test "DS-SLOTMAP-04 Given any operations, when they have run, then len is the inserts minus the successful removes and agrees with a model":
    let outcome = check(opsGen(),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        let md = play(ops)
        if md.map.len != md.inserts - md.removes: return false
        if md.map.len != md.live.len: return false
        for h in md.issued:
          if md.map.get(h) != md.modelValue(h) or md.map.contains(h) != md.modelValue(h).isSome:
            return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SLOTMAP-05
  test "DS-SLOTMAP-05 Given a removed handle, when its slot is reused, then the old handle stays stale for get, contains, remove and put":
    let a = emptySlotMap[string]().insert("old")
    let gone = a.map.remove(a.handle)
    check gone.removed == some("old")
    let reused = gone.map.insert("new")
    check reused.handle.index == a.handle.index        # the freed slot was reused
    check reused.handle.generation == a.handle.generation + 1
    check reused.map.get(a.handle).isNone
    check not reused.map.contains(a.handle)
    check reused.map.remove(a.handle).removed.isNone
    check not reused.map.put(a.handle, "x").ok
    check reused.map.get(reused.handle) == some("new")

  # SPEC: DS-SLOTMAP-05
  test "DS-SLOTMAP-05 Given any operations, when a handle was removed, then it is never live again":
    let outcome = check(opsGen(),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        var md = Model(map: emptySlotMap[int]())
        var dead: seq[Handle]
        for op in ops:
          let before = md.live
          md = md.step(op)
          for e in before:
            if md.modelValue(e.h).isNone: dead.add e.h
          for h in dead:
            if md.map.contains(h) or md.map.get(h).isSome: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SLOTMAP-06
  test "DS-SLOTMAP-06 Given a stale or unknown handle, when removing or putting, then the map comes back unchanged":
    let outcome = check(opsGen(),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        let md = play(ops)
        let before = md.map
        let unknown = [Handle(index: -1, generation: 0), Handle(index: md.map.len + 1000, generation: 0)]
        for h in unknown:
          let r = md.map.remove(h)
          let p = md.map.put(h, 99)
          if r.removed.isSome or p.ok or not (r.map == before) or not (p.map == before): return false
        for h in md.issued:
          if not md.map.contains(h):
            let r = md.map.remove(h)
            let p = md.map.put(h, 99)
            if r.removed.isSome or p.ok or not (r.map == before) or not (p.map == before): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SLOTMAP-07
  test "DS-SLOTMAP-07 Given a live handle, when putting, then the value is replaced, the handle stays valid and the length is the same":
    let a = emptySlotMap[string]().insert("a")
    let b = a.map.insert("b")
    let r = b.map.put(a.handle, "A")
    check r.ok
    check r.map.get(a.handle) == some("A")
    check r.map.get(b.handle) == some("b")
    check r.map.len == 2 and r.map.invariantsHold
    check pairsOf(r.map).len == 2

  # SPEC: DS-SLOTMAP-08
  test "DS-SLOTMAP-08 Given removed slots, when inserting, then the free slots are reused first, most recently freed first":
    var m = emptySlotMap[int]()
    var hs: seq[Handle]
    for i in 0 ..< 4:
      let r = m.insert(i)
      m = r.map
      hs.add r.handle
    m = m.remove(hs[1]).map
    m = m.remove(hs[3]).map
    let first = m.insert(10)
    let second = first.map.insert(11)
    let third = second.map.insert(12)
    check first.handle.index == 3 and first.handle.generation == 1
    check second.handle.index == 1 and second.handle.generation == 1
    check third.handle.index == 4 and third.handle.generation == 0   # no free slot left: a new one
    check third.map.invariantsHold

  # SPEC: DS-SLOTMAP-09
  test "DS-SLOTMAP-09 Given a map, when iterating pairs, then the live handles and values come in slot order and each handle gets its value":
    let outcome = check(opsGen(),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        let md = play(ops)
        let ps = pairsOf(md.map)
        if ps.len != md.map.len: return false
        var last = -1
        for p in ps:
          if p.handle.index <= last: return false
          last = p.handle.index
          if md.modelValue(p.handle) != some(p.value): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SLOTMAP-10
  test "DS-SLOTMAP-10 Given a map the caller still uses, when inserting, removing or putting, then the map passed in is unchanged":
    let outcome = check(opsGen(),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        let md = play(ops)
        let kept = md.map
        let pairsBefore = pairsOf(kept)
        let ins = kept.insert(500)
        let rem = if md.issued.len > 0: kept.remove(md.issued[0]).map else: kept
        let put = if md.issued.len > 0: kept.put(md.issued[^1], 501).map else: kept
        discard ins.map.len + rem.len + put.len
        samePairs(pairsOf(kept), pairsBefore) and kept.len == md.map.len and kept.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SLOTMAP-11
  test "DS-SLOTMAP-11 Given any operations, when checking the structure, then the invariants hold after every step":
    let outcome = check(opsGen(),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        var md = Model(map: emptySlotMap[int]())
        for op in ops:
          md = md.step(op)
          if not md.map.invariantsHold: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SLOTMAP-12
  test "DS-SLOTMAP-12 Given a map moved in at its last use, when putting, removing or inserting into freed slots, then no allocation happens whatever the size":
    # getAllocStats() reads zero unless the build has -d:nimAllocStats (tests/test_ds_slot_map.nims),
    # so first make sure a known allocation is counted.
    let probe = getAllocStats()
    var known = newSeq[int](8)
    known[0] = 1
    check getAllocStats() - probe != default(AllocStats)
    check known[0] == 1
    for n in [10, 100, 1000]:
      check allocsOfPuts(n, 50) == default(AllocStats)
      let reuse = allocsOfReuse(n, 5)
      check reuse.removing == default(AllocStats)
      check reuse.inserting == default(AllocStats)
    # The cost the move avoids: a caller that keeps the old map pays one copy of the slots per put.
    check allocsOfPutsKeepingOld(100, 50) != default(AllocStats)

  # SPEC: DS-SLOTMAP-13
  test "DS-SLOTMAP-13 Given two maps, when compared, then equal histories are equal and a different value, handle or free list is not":
    let outcome = check(opsGen(),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        play(ops).map == play(ops).map)
    checkpoint describe(outcome)
    check outcome.passed
    let a = emptySlotMap[int]().insert(1)
    let b = emptySlotMap[int]().insert(2)
    check not (a.map == b.map)
    let two = a.map.insert(3)
    check not (a.map == two.map)
    let freed = two.map.remove(a.handle).map     # slot 0 dead, generation 1
    let direct = emptySlotMap[int]().insert(3)
    check not (freed == direct.map)
    # Only the generation differs: the same value in slot 0, fresh and after a reuse.
    let fresh = emptySlotMap[int]().insert(7).map
    let first7 = emptySlotMap[int]().insert(7)
    let reused = first7.map.remove(first7.handle).map.insert(7).map
    check not (fresh == reused) and not (reused == fresh)
    # The same count and the same first slot, and one more dead slot.
    let grown = emptySlotMap[int]().insert(7).map.insert(8)
    let longer = grown.map.remove(grown.handle).map
    check not (fresh == longer) and not (longer == fresh)
    # The same free head, a different order of the free list behind it.
    func freedInOrder(order: array[3, int]): SlotMap[int] =
      var hs: seq[Handle]
      for v in 0 ..< 3:
        let r = result.insert(v)
        result = r.map
        hs.add r.handle
      for i in order:
        let r = result.remove(hs[i])
        result = r.map
    check not (freedInOrder([0, 1, 2]) == freedInOrder([1, 0, 2]))
    check freedInOrder([0, 1, 2]) == freedInOrder([0, 1, 2])
