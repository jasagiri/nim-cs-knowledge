import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/patterns/supervisor

const Names = ["db", "cache", "web", "mail"]

func specs(restart: RestartKind = rkPermanent): seq[ChildSpec] {.raises: [].} =
  for n in Names: result.add ChildSpec(id: n, restart: restart)

func policyOf(strategy: Strategy; maxRestarts, window: int;
    kids: seq[ChildSpec] = specs()): Policy {.raises: [].} =
  let p = initPolicy(strategy, kids, maxRestarts, window)
  doAssert p.isOk
  p.value

func decide(p: Policy; h: History; child: string; reason: ExitReason;
    now: int): Decision {.raises: [].} =
  let d = onExit(p, h, child, reason, now)
  doAssert d.isOk
  d.value

# SPEC: PAT-SUPERVISOR-01
test "PAT-SUPERVISOR-01 Given one_for_one, when any child crashes, then only that child is restarted":
  let outcome = check(intIn(0, 3), proc(i: int): bool {.raises: [CatchableError].} =
    let d = decide(policyOf(stOneForOne, 5, 10), noHistory(), Names[i], erCrash, 0)
    d.kind == dkRestart and d.targets == @[Names[i]])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-SUPERVISOR-02
test "PAT-SUPERVISOR-02 Given one_for_all, when any child crashes, then every child is restarted in start order":
  let outcome = check(intIn(0, 3), proc(i: int): bool {.raises: [CatchableError].} =
    let d = decide(policyOf(stOneForAll, 5, 10), noHistory(), Names[i], erCrash, 0)
    d.kind == dkRestart and d.targets == @Names)
  checkpoint describe(outcome)
  check outcome.passed
  # A temporary sibling is never brought back.
  var kids = specs()
  kids[2].restart = rkTemporary
  let d = decide(policyOf(stOneForAll, 5, 10, kids), noHistory(), "db", erCrash, 0)
  check d.targets == @["db", "cache", "mail"]

# SPEC: PAT-SUPERVISOR-03
test "PAT-SUPERVISOR-03 Given rest_for_one, when a child crashes, then it and the children started after it are restarted in start order and earlier ones are untouched":
  let outcome = check(intIn(0, 3), proc(i: int): bool {.raises: [CatchableError].} =
    let d = decide(policyOf(stRestForOne, 5, 10), noHistory(), Names[i], erCrash, 0)
    d.kind == dkRestart and d.targets == @Names[i .. 3])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-SUPERVISOR-04
test "PAT-SUPERVISOR-04 Given the restart kinds, when a child exits, then permanent always restarts, transient only after a crash, temporary never, and an ignored exit leaves the history alone":
  let outcome = check(pair(intIn(0, 2), intIn(0, 1)), proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let kind = [rkPermanent, rkTransient, rkTemporary][x[0]]
    let reason = [erNormal, erCrash][x[1]]
    let p = policyOf(stOneForOne, 5, 10, specs(kind))
    let h = noHistory().record(3)
    let d = decide(p, h, "web", reason, 4)
    let expectRestart = kind == rkPermanent or (kind == rkTransient and reason == erCrash)
    if expectRestart: d.kind == dkRestart
    else: d.kind == dkIgnore and d.history == h and d.targets.len == 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-SUPERVISOR-05
test "PAT-SUPERVISOR-05 Given at most N restarts within T ticks, when crashes come, then the N+1th within the window escalates and crashes at least T ticks apart never do":
  let outcome = check(pair(intIn(1, 6), intIn(1, 20)), proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let (n, t) = x
    let p = policyOf(stOneForOne, n, t)
    # n crashes in the same tick are restarted, the next one escalates.
    var h = noHistory()
    var allRestarted = true
    for _ in 1 .. n:
      let d = decide(p, h, "db", erCrash, 100)
      if d.kind != dkRestart: allRestarted = false
      h = d.history
    let over = decide(p, h, "db", erCrash, 100 + t - 1)
    # crashes exactly t ticks apart: each earlier one has left the window.
    var spaced = noHistory()
    var neverEscalates = true
    for i in 0 .. 3 * n:
      let d = decide(p, spaced, "db", erCrash, i * t)
      if d.kind == dkEscalate: neverEscalates = false
      spaced = d.history
    allRestarted and over.kind == dkEscalate and neverEscalates)
  checkpoint describe(outcome)
  check outcome.passed
  # N = 0: the first restart is already too many.
  check decide(policyOf(stOneForOne, 0, 5), noHistory(), "db", erCrash, 0).kind == dkEscalate

# SPEC: PAT-SUPERVISOR-06
test "PAT-SUPERVISOR-06 Given any crash times, when the supervisor decides, then the history stays ascending and never longer than N, and escalation targets every child":
  let outcome = check(pair(intIn(1, 4), seqOf(intIn(0, 5), 0, 30)), proc(x: (int, seq[int])): bool {.raises: [CatchableError].} =
    let (n, gaps) = x
    let p = policyOf(stRestForOne, n, 8)
    var h = noHistory()
    var now = 0
    var ok = true
    for g in gaps:
      now += g
      let d = decide(p, h, "cache", erCrash, now)
      let ticks = d.history.ticks
      if ticks.len > n: ok = false
      for i in 1 ..< ticks.len:
        if ticks[i - 1] > ticks[i]: ok = false
      if d.kind == dkEscalate:
        if d.targets != @Names: ok = false
      h = d.history
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-SUPERVISOR-07
test "PAT-SUPERVISOR-07 Given a policy description, when it is built, then bad numbers, duplicate or empty ids and unknown children are errors":
  check initPolicy(stOneForOne, specs(), -1, 5).error == pbNegativeIntensity
  check initPolicy(stOneForOne, specs(), 3, 0).error == pbBadWindow
  check initPolicy(stOneForOne, @[ChildSpec(id: "a", restart: rkPermanent), ChildSpec(id: "a", restart: rkPermanent)], 3, 5).error == pbDuplicateChild
  check initPolicy(stOneForOne, @[ChildSpec(id: "", restart: rkPermanent)], 3, 5).error == pbEmptyId
  check initPolicy(stOneForOne, newSeq[ChildSpec](), 3, 5).isOk
  check onExit(policyOf(stOneForOne, 3, 5), noHistory(), "ghost", erCrash, 0).error == ueUnknownChild
  check not compiles(Policy(strategy: stOneForOne, children: @[], maxRestarts: 1, window: 1))

# SPEC: PAT-SUPERVISOR-08
test "PAT-SUPERVISOR-08 Given the same policy, history, child, reason and time, when asked twice, then the decision is the same":
  let outcome = check(pair(intIn(0, 3), seqOf(intIn(0, 40), 0, 6)), proc(x: (int, seq[int])): bool {.raises: [CatchableError].} =
    let p = policyOf(stOneForAll, 3, 20)
    var h = noHistory()
    for t in x[1]: h = h.record(t)
    decide(p, h, Names[x[0]], erCrash, 50) == decide(p, h, Names[x[0]], erCrash, 50))
  checkpoint describe(outcome)
  check outcome.passed
