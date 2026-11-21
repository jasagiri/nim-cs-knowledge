import std/[unittest, options]
import propcheck
import nimcs/patterns/saga

func stepsOf(n: int): seq[SagaStep] {.raises: [].} =
  for i in 0 ..< n:
    result.add step("s" & $i, effect("do", $i), effect("undo", $i))

func actionNames(log: seq[LogEntry]; kind: LogKind): seq[string] {.raises: [].} =
  for e in log:
    if e.kind == kind: result.add e.effect.payload

func reversedIdx(n: int): seq[string] {.raises: [].} =
  for i in countdown(n - 1, 0): result.add $i

func okIf(b: bool): EffectResult {.raises: [].} = (if b: erOk else: erFailed)

# The shell: a handler fixed by a plan of which actions fail and which compensations fail.
func planned(failAction, failComp: int): EffectHandler {.raises: [].} =
  result = proc(e: Effect): EffectResult {.noSideEffect, raises: [].} =
    if e.name == "do": okIf(e.payload != $failAction)
    else: okIf(e.payload != $failComp)

# SPEC: PAT-SAGA-01
test "PAT-SAGA-01 Given any number of steps that all succeed, when run, then it completes with the actions in order and no compensation":
  let outcome = check(intIn(0, 12), proc(n: int): bool {.raises: [CatchableError].} =
    let s = run(stepsOf(n), planned(-1, -1))
    var expected: seq[string]
    for i in 0 ..< n: expected.add $i
    s.outcome == soCompleted and s.log.actionNames(lkAction) == expected and
      s.log.actionNames(lkCompensation).len == 0 and s.nextEffect.isNone and s.pending.len == 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-SAGA-02
test "PAT-SAGA-02 Given step k fails, when run, then actions up to k ran, then compensations of k-1 down to 0 in reverse, and k itself is not compensated":
  let outcome = check(pair(intIn(1, 12), intIn(0, 11)), proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let n = x[0]
    let k = x[1] mod n
    let s = run(stepsOf(n), planned(k, -1))
    var ran: seq[string]
    for i in 0 .. k: ran.add $i
    s.outcome == soCompensated and s.log.actionNames(lkAction) == ran and
      s.log.actionNames(lkCompensation) == reversedIdx(k) and
      s.log[k].ok == false and s.nextEffect.isNone)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-SAGA-03
test "PAT-SAGA-03 Given the first step fails, when run, then it ends compensated with one log entry and no compensation":
  let s = run(stepsOf(3), planned(0, -1))
  check s.outcome == soCompensated
  check s.log.len == 1
  check s.log[0].ok == false
  check s.log[0].kind == lkAction

# SPEC: PAT-SAGA-04
test "PAT-SAGA-04 Given a compensation fails, when run, then it stops stuck, nothing further runs, and pending lists the rest in order":
  let outcome = check(pair(intIn(2, 12), pair(intIn(1, 11), intIn(0, 11))), proc(x: (int, (int, int))): bool {.raises: [CatchableError].} =
    let n = x[0]
    let k = 1 + (x[1][0] - 1) mod (n - 1)       # failing action, 1 .. n-1
    let c = x[1][1] mod k                        # failing compensation among 0 .. k-1
    let s = run(stepsOf(n), planned(k, c))
    var restNames: seq[string]
    for i in countdown(c, 0): restNames.add $i   # the failed one is retried first: it is still pending
    var pend: seq[string]
    for e in s.pending: pend.add e.payload
    s.outcome == soStuck and s.nextEffect.isNone and pend == restNames and
      s.log[^1].kind == lkCompensation and s.log[^1].ok == false and
      s.log.actionNames(lkCompensation) == reversedIdx(k)[0 .. k - 1 - c])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-SAGA-05
test "PAT-SAGA-05 Given any failing step, when run to the end, then every action that succeeded has exactly one successful compensation":
  let outcome = check(pair(intIn(0, 12), intIn(0, 14)), proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let s = run(stepsOf(x[0]), planned(x[1], -1))
    var okActions, okComps: seq[string]
    for e in s.log:
      if e.ok and e.kind == lkAction: okActions.add e.effect.payload
      if e.ok and e.kind == lkCompensation: okComps.add e.effect.payload
    if s.outcome == soCompleted: okComps.len == 0 and okActions.len == x[0]
    else: okComps == reversedIdx(okActions.len))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-SAGA-06
test "PAT-SAGA-06 Given a finished or stuck saga, when more results are fed, then the saga does not change":
  let outcome = check(pair(intIn(0, 8), pair(intIn(0, 10), boolean())), proc(x: (int, (int, bool))): bool {.raises: [CatchableError].} =
    let done = run(stepsOf(x[0]), planned(x[1][0], -1))
    let stuck = run(stepsOf(5), planned(3, 1))
    done.feed(okIf(x[1][1])) == done and stuck.feed(okIf(x[1][1])) == stuck and
      done.feed(erOk).feed(erFailed) == done)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-SAGA-07
test "PAT-SAGA-07 Given the same plan, when an imperative shell steps through nextEffect and feed, then it ends in the saga that run returns":
  let outcome = check(pair(intIn(0, 10), pair(intIn(0, 12), intIn(0, 12))), proc(x: (int, (int, int))): bool {.raises: [CatchableError].} =
    let steps = stepsOf(x[0])
    let handler = planned(x[1][0], x[1][1])
    var s = start(steps)
    var performed: seq[Effect]
    while true:
      let e = s.nextEffect
      if e.isNone: break
      performed.add e.get
      s = s.feed(handler(e.get))
    var logged: seq[Effect]
    for entry in s.log: logged.add entry.effect
    s == run(steps, handler) and performed == logged)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-SAGA-08
test "PAT-SAGA-08 Given no steps, when started, then it is completed with an empty log":
  let s = start(newSeq[SagaStep]())
  check s.outcome == soCompleted
  check s.nextEffect.isNone
  check s.log.len == 0
  check run(newSeq[SagaStep](), planned(-1, -1)) == s

# SPEC: PAT-SAGA-09
test "PAT-SAGA-09 Given a started saga, when asked what to do, then it names the first action; a pure start leaves the steps untouched":
  let steps = @[step("pay", effect("charge", "42"), effect("refund", "42")), step("ship", effect("pack"), effect("unpack"))]
  let s = start(steps)
  check s.outcome == soRunning
  check s.nextEffect.get == effect("charge", "42")
  check s.feed(erOk).nextEffect.get == effect("pack")
  check s.feed(erOk).feed(erFailed).nextEffect.get == effect("refund", "42")
  check start(steps) == s
