## Command buffer: read, decide, then write, instead of changing a collection while reading it.
##
## A game step has to remove units that die and add units that split, and the natural loop does both
## to the collection it is reading. In Nim that fails at run time (the `for` loop over a `seq`
## asserts that the length did not change), and the ways around it that compile are a copy of the
## collection per frame or a `ref` per unit that several places mutate. This module splits the work
## in two. `plan` only reads the world and returns the changes as data: a `seq[Cmd]`. `applyAll`
## applies them in order to a world the caller moves in. Units live in a `SlotMap`, so a command
## names its target by `Handle`; a command whose handle is stale (the unit was despawned earlier in
## the batch, or before it) does nothing, which makes a double despawn harmless and a damage after a
## despawn ignored. The shell of the pattern is the same as a command log: the plan can be inspected,
## logged, replayed or sent elsewhere before it is applied (see `command` for undo, and
## `functional_core` for effects as data).
##
## Rules of the example world. `plan` with a damage of zero or less returns no commands (healing
## is not modelled). A live unit whose `hp` is at most the damage is despawned; it does not split.
## Any other unit takes the damage, and a unit with `splits` set whose `hp` falls from above
## `SplitThreshold` to `SplitThreshold` or below spawns one child with the parent's new `hp` and
## `splits` unset, so a unit splits at most once and children do not split. Units spawned during a
## step are not visited by that step's `plan`: it was computed from the world before the step.

import std/options
import nimcs/ds/slot_map

const
  SplitThreshold* = 3   ## a splitting unit spawns a child when damage takes its hp from above this to this or below

type
  Unit* = object
    hp*: int
    splits*: bool
  World* = object
    units*: SlotMap[Unit]
  CmdKind* = enum
    ckSpawn, ckDespawn, ckDamage
  Cmd* = object
    ## A change to the world, as data. `ckDamage` lowers `hp` and never removes the unit;
    ## removal is a separate `ckDespawn`, which `plan` emits.
    case kind*: CmdKind
    of ckSpawn:
      unit*: Unit
    of ckDespawn:
      target*: Handle
    of ckDamage:
      victim*: Handle
      amount*: int

func emptyWorld*(): World {.raises: [].} =
  World(units: emptySlotMap[Unit]())

func `==`*(a, b: Unit): bool {.raises: [].} =
  a.hp == b.hp and a.splits == b.splits

func `==`*(a, b: World): bool {.raises: [].} =
  a.units == b.units

func `==`*(a, b: Cmd): bool {.raises: [].} =
  if a.kind != b.kind: return false
  case a.kind
  of ckSpawn: a.unit == b.unit
  of ckDespawn: a.target == b.target
  of ckDamage: a.victim == b.victim and a.amount == b.amount

func spawnCmd*(unit: Unit): Cmd {.raises: [].} =
  Cmd(kind: ckSpawn, unit: unit)

func despawnCmd*(target: Handle): Cmd {.raises: [].} =
  Cmd(kind: ckDespawn, target: target)

func damageCmd*(victim: Handle; amount: int): Cmd {.raises: [].} =
  Cmd(kind: ckDamage, victim: victim, amount: amount)

func spawn*(w: sink World; unit: Unit): tuple[world: World, handle: Handle] {.raises: [].} =
  ## Adds a unit directly and returns its handle (a `ckSpawn` command does not report one).
  var cur = w
  let r = move(cur.units).insert(unit)
  (World(units: r.map), r.handle)

func satSub(hp, amount: int): int =
  ## `hp - amount`, held at the ends of `int` instead of wrapping.
  if amount > 0 and hp < low(int) + amount: low(int)
  elif amount < 0 and hp > high(int) + amount: high(int)
  else: hp - amount

func plan*(w: World; damage: int): seq[Cmd] {.raises: [].} =
  ## Reads only: the commands one step with `damage` would apply, in slot order.
  if damage <= 0: return @[]
  for h, u in w.units.pairs:
    if u.hp <= damage:
      result.add despawnCmd(h)
    else:
      result.add damageCmd(h, damage)
      let left = u.hp - damage
      if u.splits and u.hp > SplitThreshold and left <= SplitThreshold:
        result.add spawnCmd(Unit(hp: left, splits: false))

func applyCmd*(w: sink World; c: Cmd): World {.raises: [].} =
  ## One command. A handle that is stale or unknown changes nothing.
  var cur = w
  case c.kind
  of ckSpawn:
    let r = move(cur.units).insert(c.unit)
    World(units: r.map)
  of ckDespawn:
    let r = move(cur.units).remove(c.target)
    World(units: r.map)
  of ckDamage:
    let u = cur.units.get(c.victim)
    if u.isNone: return cur
    let r = move(cur.units).put(c.victim, Unit(hp: satSub(u.get.hp, c.amount), splits: u.get.splits))
    World(units: r.map)

func applyAll*(w: sink World; cmds: openArray[Cmd]): World {.raises: [].} =
  ## The commands in order; the same as folding `applyCmd` over them.
  var cur = w
  for c in cmds:
    cur = applyCmd(cur, c)
  cur

func step*(w: sink World; damage: int): World {.raises: [].} =
  ## Plan from the world as it is, then apply.
  let cmds = plan(w, damage)
  applyAll(w, cmds)
