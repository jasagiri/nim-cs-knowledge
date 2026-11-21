import std/[unittest, options]
import propcheck
import nimcs/ds/slot_map
import nimcs/patterns/command_buffer

type Built = object
  world: World
  issued: seq[Handle]

func build(ops: seq[int]): Built =
  ## Ops 0..11 spawn a unit (hp 1..12, splitting unless the op is a multiple of 3); 12..19 despawn
  ## an issued handle, so the free slots get reused by later spawns.
  result.world = emptyWorld()
  for op in ops:
    if op < 12 or result.issued.len == 0:
      let r = result.world.spawn(Unit(hp: op + 1, splits: op mod 3 != 0))
      result.world = r.world
      result.issued.add r.handle
    else:
      result.world = result.world.applyCmd(despawnCmd(result.issued[op mod result.issued.len]))

func cmdsOf(ops: seq[int]; issued: seq[Handle]): seq[Cmd] =
  ## Spawns, despawns and damages on issued handles (live or stale) and on one unknown handle.
  for op in ops:
    let h = if issued.len == 0 or op == 29: Handle(index: 999, generation: 0) else: issued[op mod issued.len]
    if op < 8: result.add spawnCmd(Unit(hp: op, splits: op mod 2 == 0))
    elif op < 16: result.add despawnCmd(h)
    else: result.add damageCmd(h, op - 18)

func worldGen(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(0, 19), 0, 25)

func cmdGen(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(0, 29), 0, 20)

func liveUnits(w: World): seq[tuple[handle: Handle, value: Unit]] =
  for h, u in w.units.pairs: result.add (handle: h, value: u)

func isLiveIn(w: World; h: Handle): bool =
  w.units.contains(h)

proc allocsOfApply(n, k: int; despawn: bool): AllocStats =
  ## Allocations of `k` damage (or despawn) commands applied to a world of `n` units that is moved in.
  var w = emptyWorld()
  var hs: seq[Handle]
  for i in 0 ..< n:
    let r = w.spawn(Unit(hp: 100, splits: false))
    w = r.world
    hs.add r.handle
  var cmds: seq[Cmd]
  for j in 0 ..< k:
    cmds.add(if despawn: despawnCmd(hs[j]) else: damageCmd(hs[j], 1))
  let before = getAllocStats()
  w = applyAll(w, cmds)
  result = getAllocStats() - before
  doAssert w.units.len == (if despawn: n - k else: n)

suite "command_buffer":
  # SPEC: PAT-COMMANDBUFFER-01
  test "PAT-COMMANDBUFFER-01 Given any world and damage, when planning, then the world is equal to before and equal worlds give equal plans":
    let outcome = check(pair(worldGen(), intIn(-2, 12)),
      proc(a: (seq[int], int)): bool {.raises: [CatchableError].} =
        let w = build(a[0]).world
        let before = build(a[0]).world
        let p = plan(w, a[1])
        w == before and liveUnits(w).len == w.units.len and p == plan(before, a[1]))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: PAT-COMMANDBUFFER-02
  test "PAT-COMMANDBUFFER-02 Given any world, when a step runs, then a unit with hp at most the damage is gone and every other unit lost exactly the damage":
    let outcome = check(pair(worldGen(), intIn(1, 12)),
      proc(a: (seq[int], int)): bool {.raises: [CatchableError].} =
        let w = build(a[0]).world
        let d = a[1]
        let after = step(w, d)
        for (h, u) in liveUnits(w):
          let now = after.units.get(h)
          if u.hp <= d:
            if now.isSome: return false
          else:
            if now.isNone or now.get.hp != u.hp - d or now.get.splits != u.splits: return false
        after.units.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: PAT-COMMANDBUFFER-03
  test "PAT-COMMANDBUFFER-03 Given a despawn and a damage of the same handle in one batch, when applied, then the damage is ignored":
    let outcome = check(pair(worldGen(), intIn(-5, 20)),
      proc(a: (seq[int], int)): bool {.raises: [CatchableError].} =
        let b = build(a[0])
        if b.issued.len == 0: return true
        for h in b.issued:
          let with = applyAll(b.world, [despawnCmd(h), damageCmd(h, a[1])])
          let without = applyAll(b.world, [despawnCmd(h)])
          if not (with == without): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: PAT-COMMANDBUFFER-04
  test "PAT-COMMANDBUFFER-04 Given a despawn, when it is applied twice, then the world is the same as after once, even with a spawn between":
    let outcome = check(worldGen(),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        let b = build(ops)
        let extra = spawnCmd(Unit(hp: 9, splits: true))
        for h in b.issued:
          let d = despawnCmd(h)
          if not (applyAll(b.world, [d, d]) == applyAll(b.world, [d])): return false
          if not (applyAll(b.world, [d, extra, d]) == applyAll(b.world, [d, extra])): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: PAT-COMMANDBUFFER-05
  test "PAT-COMMANDBUFFER-05 Given a step that spawns children, when it has run, then each child has the hp the plan gave it and was not damaged by that step":
    let outcome = check(pair(worldGen(), intIn(1, 12)),
      proc(a: (seq[int], int)): bool {.raises: [CatchableError].} =
        let w = build(a[0]).world
        let cmds = plan(w, a[1])
        var born: seq[Unit]
        for c in cmds:
          if c.kind == ckSpawn: born.add c.unit
        let after = applyAll(w, cmds)
        var found: seq[Unit]
        for (h, u) in liveUnits(after):
          if not w.isLiveIn(h): found.add u
        if found.len != born.len: return false
        for u in found:
          var matched = false
          for i in 0 ..< born.len:
            if born[i] == u:
              born.delete(i)
              matched = true
              break
          if not matched or u.splits: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: PAT-COMMANDBUFFER-06
  test "PAT-COMMANDBUFFER-06 Given any commands, when applied together, then the world equals applying them one at a time":
    let outcome = check(pair(worldGen(), cmdGen()),
      proc(a: (seq[int], seq[int])): bool {.raises: [CatchableError].} =
        let b = build(a[0])
        let cmds = cmdsOf(a[1], b.issued)
        var folded = b.world
        for c in cmds:
          folded = folded.applyCmd(c)
        applyAll(b.world, cmds) == folded and folded.units.invariantsHold)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: PAT-COMMANDBUFFER-07
  test "PAT-COMMANDBUFFER-07 Given handles that are stale or unknown, when their damage and despawn are applied, then the world is unchanged":
    let outcome = check(worldGen(),
      proc(ops: seq[int]): bool {.raises: [CatchableError].} =
        let b = build(ops)
        var stale: seq[Handle] = @[Handle(index: 999, generation: 0), Handle(index: -1, generation: 0)]
        for h in b.issued:
          if not b.world.isLiveIn(h): stale.add h
        for h in stale:
          if not (applyAll(b.world, [damageCmd(h, 5), despawnCmd(h), damageCmd(h, -5)]) == b.world):
            return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: PAT-COMMANDBUFFER-08
  test "PAT-COMMANDBUFFER-08 Given equal worlds and equal commands, when applied, then the results are equal":
    let outcome = check(pair(worldGen(), pair(cmdGen(), intIn(-2, 12))),
      proc(a: (seq[int], (seq[int], int))): bool {.raises: [CatchableError].} =
        let x = build(a[0])
        let y = build(a[0])
        let cmds = cmdsOf(a[1][0], x.issued)
        applyAll(x.world, cmds) == applyAll(y.world, cmdsOf(a[1][0], y.issued)) and
          step(x.world, a[1][1]) == step(y.world, a[1][1]))
    checkpoint describe(outcome)
    check outcome.passed
    # Equality tells apart what differs: a field of a unit, the kind of a command, its handle or amount.
    let h0 = Handle(index: 0, generation: 0)
    check not (Unit(hp: 1, splits: true) == Unit(hp: 1, splits: false))
    check not (Unit(hp: 1, splits: true) == Unit(hp: 2, splits: true))
    check not (despawnCmd(h0) == damageCmd(h0, 1))
    check not (damageCmd(h0, 1) == damageCmd(h0, 2))
    check not (damageCmd(h0, 1) == damageCmd(Handle(index: 1, generation: 0), 1))
    check spawnCmd(Unit(hp: 1, splits: false)) == spawnCmd(Unit(hp: 1, splits: false))

  # SPEC: PAT-COMMANDBUFFER-09
  test "PAT-COMMANDBUFFER-09 Given a splitting unit, when damage takes it across the threshold, then exactly one child with its new hp appears, and in no other case":
    check SplitThreshold == 3
    proc childrenOf(hp: int; splits: bool; damage: int): seq[Unit] =
      let w = emptyWorld().spawn(Unit(hp: hp, splits: splits)).world
      for c in plan(w, damage):
        if c.kind == ckSpawn: result.add c.unit
    check childrenOf(4, true, 1) == @[Unit(hp: 3, splits: false)]     # 4 -> 3: reaches the threshold
    check childrenOf(5, true, 4) == @[Unit(hp: 1, splits: false)]     # well below it
    check childrenOf(5, true, 1).len == 0                             # 5 -> 4: still above it
    check childrenOf(3, true, 1).len == 0                             # already at it: crossed before
    check childrenOf(2, true, 1).len == 0
    check childrenOf(4, false, 1).len == 0                            # does not split
    check childrenOf(4, true, 4).len == 0                             # dies: no child
    check childrenOf(4, true, 9).len == 0
    check childrenOf(6, true, 3).len == 1 and childrenOf(6, true, 3)[0].hp == 3

  # SPEC: PAT-COMMANDBUFFER-10
  test "PAT-COMMANDBUFFER-10 Given a damage of zero or less, when planning or stepping, then there are no commands and the world is unchanged":
    let outcome = check(pair(worldGen(), intIn(-5, 0)),
      proc(a: (seq[int], int)): bool {.raises: [CatchableError].} =
        let w = build(a[0]).world
        plan(w, a[1]).len == 0 and step(w, a[1]) == w)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: PAT-COMMANDBUFFER-11
  test "PAT-COMMANDBUFFER-11 Given single commands, when applied, then spawn adds a unit, damage lowers hp without removing it and stops at the ends of int":
    let a = emptyWorld().spawn(Unit(hp: 5, splits: false))
    let grown = a.world.applyCmd(spawnCmd(Unit(hp: 7, splits: true)))
    check grown.units.len == 2
    let hit = grown.applyCmd(damageCmd(a.handle, 9))
    check hit.units.get(a.handle) == some(Unit(hp: -4, splits: false))     # damage alone never despawns
    check hit.applyCmd(damageCmd(a.handle, -10)).units.get(a.handle) == some(Unit(hp: 6, splits: false))
    let low = emptyWorld().spawn(Unit(hp: low(int) + 1, splits: false))
    check low.world.applyCmd(damageCmd(low.handle, 5)).units.get(low.handle) == some(Unit(hp: low(int), splits: false))
    let high = emptyWorld().spawn(Unit(hp: high(int) - 1, splits: false))
    check high.world.applyCmd(damageCmd(high.handle, -5)).units.get(high.handle) == some(Unit(hp: high(int), splits: false))
    let lowest = emptyWorld().spawn(Unit(hp: low(int), splits: false))
    check lowest.world.applyCmd(damageCmd(lowest.handle, 1)).units.get(lowest.handle) == some(Unit(hp: low(int), splits: false))

  # SPEC: PAT-COMMANDBUFFER-12
  test "PAT-COMMANDBUFFER-12 Given a world moved in at its last use, when damage or despawn commands are applied, then no allocation happens whatever the size":
    # getAllocStats() reads zero unless the build has -d:nimAllocStats (tests/test_patterns_command_buffer.nims),
    # so first make sure a known allocation is counted.
    let probe = getAllocStats()
    var known = newSeq[int](8)
    known[0] = 1
    check getAllocStats() - probe != default(AllocStats)
    check known[0] == 1
    for n in [10, 100, 1000]:
      check allocsOfApply(n, 5, false) == default(AllocStats)
      check allocsOfApply(n, 5, true) == default(AllocStats)
