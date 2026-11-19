## Functional core, imperative shell: decide with a pure function, act with a thin loop.
##
## The core is a `func` from (configuration, current state, new input) to a decision: the next
## state plus a list of effect descriptions, which are plain data. It never touches the world, so
## every rule about when the system acts is a property of a function. The shell is the small loop
## that reads an input, calls the core and performs the effects it returned; it holds no rules.
## Use it whenever logic and I/O are tangled. The example is a thermostat with a dead band: it
## switches only when the reading leaves the band, so the same reading twice never acts twice.

import nimcs/fp/result

type
  HeaterState* = enum
    hsOff, hsOn

  Config* = object
    ## Temperatures are in tenths of a degree.
    target*: int
    band*: int   ## half-width of the dead band, never negative (see `initConfig`)

  EffectKind* = enum
    ekSetHeater, ekLog

  Effect* = object
    ## An effect described, not performed. The shell decides how to perform it.
    case kind*: EffectKind
    of ekSetHeater:
      heater*: HeaterState
    of ekLog:
      line*: string

  Decision* = object
    state*: HeaterState
    effects*: seq[Effect]

func `==`*(a, b: Effect): bool {.raises: [].} =
  if a.kind != b.kind: return false
  case a.kind
  of ekSetHeater: a.heater == b.heater
  of ekLog: a.line == b.line

func initConfig*(target, band: int): Result[Config, string] {.raises: [].} =
  ## Smart constructor: a negative band has no meaning.
  if band < 0: err(Config, "band must not be negative")
  else: ok(Config(target: target, band: band), string)

func decide*(cfg: Config; current: HeaterState; reading: int): Decision {.raises: [].} =
  ## Pure decision. Inside the dead band (`|reading - target| <= band`) the state is kept and no
  ## effect is emitted; outside it the heater is driven toward the target, and a change is
  ## reported as one `ekSetHeater` followed by one `ekLog`.
  let wanted =
    if reading < cfg.target - cfg.band: hsOn
    elif reading > cfg.target + cfg.band: hsOff
    else: current
  if wanted == current:
    Decision(state: current, effects: @[])
  else:
    let word = if wanted == hsOn: "on" else: "off"
    Decision(state: wanted, effects: @[
      Effect(kind: ekSetHeater, heater: wanted),
      Effect(kind: ekLog, line: "heater " & word & " at " & $reading)])
