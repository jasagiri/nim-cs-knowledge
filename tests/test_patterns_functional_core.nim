import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/patterns/functional_core

# The imperative shell lives here: it owns the only mutable thing (the world) and does whatever
# the core's effect descriptions say. It contains no decisions.
type World = object
  heater: HeaterState
  log: seq[string]

proc perform(world: var World; effect: Effect) =
  case effect.kind
  of ekSetHeater: world.heater = effect.heater
  of ekLog: world.log.add effect.line

proc runShell(cfg: Config; readings: seq[int]): (World, HeaterState) =
  ## Reads, asks the core, performs. The core state is threaded through by the shell.
  var world = World(heater: hsOff)
  var state = hsOff
  for r in readings:
    let d = cfg.decide(state, r)
    for e in d.effects: world.perform(e)
    state = d.state
  (world, state)

func config(): Config {.raises: [].} = Config(target: 200, band: 15)

# SPEC: PAT-FUNCTIONALCORE-01
test "PAT-FUNCTIONALCORE-01 Given any state and reading, when decided, then effects name the new state exactly when it changed":
  let cfg = config()
  let outcome = check(pair(boolean(), intIn(100, 300)), proc(p: (bool, int)): bool {.raises: [CatchableError].} =
    let current = if p[0]: hsOn else: hsOff
    let d = cfg.decide(current, p[1])
    if d.state == current:
      d.effects.len == 0
    else:
      d.effects.len == 2 and d.effects[0] == Effect(kind: ekSetHeater, heater: d.state) and
        d.effects[1].kind == ekLog)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-FUNCTIONALCORE-02
test "PAT-FUNCTIONALCORE-02 Given any reading, when decided again from the resulting state, then there are no effects":
  let cfg = config()
  let outcome = check(pair(boolean(), intIn(100, 300)), proc(p: (bool, int)): bool {.raises: [CatchableError].} =
    let current = if p[0]: hsOn else: hsOff
    let first = cfg.decide(current, p[1])
    let second = cfg.decide(first.state, p[1])
    second.effects.len == 0 and second.state == first.state)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-FUNCTIONALCORE-03
test "PAT-FUNCTIONALCORE-03 Given a reading inside the dead band, when decided, then the state is kept and nothing is emitted":
  let cfg = config()
  let outcome = check(pair(boolean(), intIn(185, 215)), proc(p: (bool, int)): bool {.raises: [CatchableError].} =
    let current = if p[0]: hsOn else: hsOff
    let d = cfg.decide(current, p[1])
    d.state == current and d.effects.len == 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-FUNCTIONALCORE-03
test "PAT-FUNCTIONALCORE-03 Given readings outside the band, when decided, then too cold switches on and too warm switches off":
  let cfg = config()
  check cfg.decide(hsOff, 184).state == hsOn
  check cfg.decide(hsOn, 216).state == hsOff
  check cfg.decide(hsOn, 184).effects.len == 0
  check cfg.decide(hsOff, 216).effects.len == 0

# SPEC: PAT-FUNCTIONALCORE-04
test "PAT-FUNCTIONALCORE-04 Given any readings, when the shell runs the core, then the world ends in the core's state with one log line per switch":
  let cfg = config()
  let outcome = check(seqOf(intIn(100, 300), 0, 30), proc(rs: seq[int]): bool {.raises: [CatchableError].} =
    let (world, state) = runShell(cfg, rs)
    var switches = 0
    var s = hsOff
    for r in rs:
      let d = cfg.decide(s, r)
      if d.state != s: inc switches
      s = d.state
    world.heater == state and world.log.len == switches)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-FUNCTIONALCORE-05
test "PAT-FUNCTIONALCORE-05 Given a negative band, when the config is built, then it is rejected; a valid one is kept":
  check initConfig(200, -1).isErr
  let ok1 = initConfig(200, 0)
  check ok1.isOk
  check ok1.value.target == 200
  check ok1.value.band == 0
