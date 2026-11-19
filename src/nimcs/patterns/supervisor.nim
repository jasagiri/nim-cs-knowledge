## Supervisor: let it crash, and decide what to restart as a pure function (ADR-NCK-0002).
##
## A worker does not defend against every failure; when it dies, its supervisor decides. The
## decision is `onExit(policy, history, child, reason, now): Decision`: a value computed from a
## sealed `Policy` (strategy, children in start order, restart intensity), the `History` of earlier
## restart times, the child that exited and why. Time is data: `now` is a tick number the host
## passes in, so the module has no clock and the decision replays exactly. The decision is one of
## ignore (the exit needs no restart), restart these children (the host stops them in reverse
## start order, then starts them in start order), or escalate (more than `maxRestarts` restarts
## within `window` ticks: the supervisor gives up, stops every child and fails its own parent).
##
## Strategies: one_for_one restarts only the child that exited; one_for_all restarts every child;
## rest_for_one restarts the child and the children started after it. A temporary child is never
## restarted, and so is never brought back as a sibling either. A restart is allowed when the
## number of restarts within the last `window` ticks, counting this one, is at most `maxRestarts`.

import std/algorithm
import nimcs/fp/result

type
  Strategy* = enum
    stOneForOne, stOneForAll, stRestForOne

  RestartKind* = enum
    rkPermanent   ## always restarted
    rkTransient   ## restarted after a crash, not after a normal exit
    rkTemporary   ## never restarted

  ExitReason* = enum
    erNormal, erCrash

  ChildSpec* = object
    id*: string
    restart*: RestartKind

  Policy* {.requiresInit.} = object
    ## Sealed: only `initPolicy` builds one, so the numbers and the children are always valid.
    strategy: Strategy
    children: seq[ChildSpec]
    maxRestarts: int
    window: int

  PolicyError* = enum
    pbNegativeIntensity, pbBadWindow, pbEmptyId, pbDuplicateChild

  ExitError* = enum
    ueUnknownChild

  History* = object
    ## The ticks of the restarts still remembered, ascending.
    ticks*: seq[int]

  DecisionKind* = enum
    dkIgnore, dkRestart, dkEscalate

  Decision* = object
    kind*: DecisionKind
    targets*: seq[string]   ## to restart (start order), or every child when escalating
    history*: History       ## the history to pass to the next `onExit`

func noHistory*(): History {.raises: [].} = History(ticks: @[])

func `==`*(a, b: History): bool {.raises: [].} = a.ticks == b.ticks

func `==`*(a, b: Decision): bool {.raises: [].} =
  a.kind == b.kind and a.targets == b.targets and a.history == b.history

func record*(h: History; tick: int): History {.raises: [].} =
  ## Adds a restart time, keeping the ticks ascending.
  result = h
  result.ticks.add tick
  result.ticks.sort()

func initPolicy*(strategy: Strategy; children: seq[ChildSpec]; maxRestarts, window: int):
    Result[Policy, PolicyError] {.raises: [].} =
  ## `maxRestarts` is 0 or more, `window` at least 1 tick; ids are non-empty and unique.
  if maxRestarts < 0: return err(Policy, pbNegativeIntensity)
  if window < 1: return err(Policy, pbBadWindow)
  for i, c in children:
    if c.id.len == 0: return err(Policy, pbEmptyId)
    for j in 0 ..< i:
      if children[j].id == c.id: return err(Policy, pbDuplicateChild)
  ok(Policy(strategy: strategy, children: children, maxRestarts: maxRestarts, window: window),
    PolicyError)

func childIds*(p: Policy): seq[string] {.raises: [].} =
  for c in p.children: result.add c.id

func within(now, t, window: int): bool =
  ## Is the restart at `t` inside the last `window` ticks before `now`? The difference is taken
  ## in unsigned arithmetic so extreme ticks cannot overflow; a tick after `now` counts as inside.
  if t >= now: true
  else: uint64(now) - uint64(t) < uint64(window)

func onExit*(p: Policy; history: History; child: string; reason: ExitReason; now: int):
    Result[Decision, ExitError] {.raises: [].} =
  ## What to do when `child` exits with `reason` at tick `now`.
  var at = -1
  for i, c in p.children:
    if c.id == child: at = i
  if at < 0: return err(Decision, ueUnknownChild)
  let spec = p.children[at]
  let wanted = case spec.restart
    of rkPermanent: true
    of rkTransient: reason == erCrash
    of rkTemporary: false
  if not wanted:
    return ok(Decision(kind: dkIgnore, targets: @[], history: history), ExitError)
  var recent = noHistory()
  for t in history.ticks:
    if within(now, t, p.window): recent.ticks.add t
  if recent.ticks.len + 1 > p.maxRestarts:
    return ok(Decision(kind: dkEscalate, targets: p.childIds, history: recent), ExitError)
  var targets: seq[string]
  case p.strategy
  of stOneForOne:
    targets.add child
  of stOneForAll:
    for i, c in p.children:
      if i == at or c.restart != rkTemporary: targets.add c.id
  of stRestForOne:
    for i in at ..< p.children.len:
      if i == at or p.children[i].restart != rkTemporary: targets.add p.children[i].id
  ok(Decision(kind: dkRestart, targets: targets, history: recent.record(now)), ExitError)
