import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/patterns/circuit_breaker

func cfgOf(threshold, ticks: int): BreakerConfig {.raises: [].} =
  let r = initConfig(threshold, ticks)
  doAssert r.isOk
  r.value

type
  EventKind = enum
    evAllow, evSuccess, evFailure

func eventOf(code: int): EventKind {.raises: [].} =
  case code mod 3
  of 0: evAllow
  of 1: evSuccess
  else: evFailure

# SPEC: PAT-CIRCUITBREAKER-01
test "PAT-CIRCUITBREAKER-01 Given a fresh breaker, when a call is asked at any time, then it is closed and allows":
  let outcome = check(intIn(0, 1_000_000), proc(now: int): bool {.raises: [CatchableError].} =
    let c = cfgOf(3, 10)
    let b = closedBreaker()
    let (b2, d) = b.allow(c, now)
    b.state == bsClosed and b.consecutiveFailures == 0 and d == dAllow and b2 == b)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-CIRCUITBREAKER-02
test "PAT-CIRCUITBREAKER-02 Given any threshold, when failures arrive, then it opens at exactly the threshold-th consecutive failure":
  let outcome = check(pair(intIn(1, 20), intIn(0, 1000)), proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let c = cfgOf(x[0], 5)
    var b = closedBreaker()
    for i in 1 .. x[0]:
      if b.state != bsClosed or b.consecutiveFailures != i - 1: return false
      b = b.recordFailure(c, x[1])
    b.state == bsOpen and b.openedAtOf == x[1])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-CIRCUITBREAKER-03
test "PAT-CIRCUITBREAKER-03 Given failures below the threshold, when a success arrives, then the count restarts":
  let outcome = check(pair(intIn(2, 20), intIn(1, 19)), proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let c = cfgOf(x[0], 5)
    let k = min(x[1], x[0] - 1)
    var b = closedBreaker()
    for _ in 1 .. k: b = b.recordFailure(c, 0)
    let s = b.recordSuccess
    b.consecutiveFailures == k and s == closedBreaker())
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-CIRCUITBREAKER-04
test "PAT-CIRCUITBREAKER-04 Given an open breaker, when asked before the pause is over, then it refuses and is unchanged; at the pause it admits a probe":
  let outcome = check(pair(pair(intIn(1, 1000), intIn(0, 100_000)), intIn(0, 3000)), proc(x: ((int, int), int)): bool {.raises: [CatchableError].} =
    let ticks = x[0][0]
    let openedAt = x[0][1]
    let c = cfgOf(1, ticks)
    let b = closedBreaker().recordFailure(c, openedAt)
    let now = openedAt + x[1]
    let (b2, d) = b.allow(c, now)
    if x[1] < ticks: d == dReject and b2 == b
    else: d == dAllow and b2.state == bsHalfOpen)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-CIRCUITBREAKER-04
test "PAT-CIRCUITBREAKER-04 Given an open breaker, when the clock reads earlier than the opening, then it refuses":
  let c = cfgOf(1, 10)
  let b = closedBreaker().recordFailure(c, 100)
  let (b2, d) = b.allow(c, 50)
  check d == dReject
  check b2 == b

# SPEC: PAT-CIRCUITBREAKER-05
test "PAT-CIRCUITBREAKER-05 Given a half-open breaker with a probe in flight, when another call is asked, then it refuses and is unchanged":
  let c = cfgOf(1, 10)
  let open = closedBreaker().recordFailure(c, 0)
  let (probing, d1) = open.allow(c, 10)
  check d1 == dAllow
  check probing.state == bsHalfOpen
  let (again, d2) = probing.allow(c, 11)
  check d2 == dReject
  check again == probing

# SPEC: PAT-CIRCUITBREAKER-06
test "PAT-CIRCUITBREAKER-06 Given a probe, when it succeeds then the breaker closes; when it fails then it opens again from that time":
  let outcome = check(pair(intIn(1, 100), intIn(0, 10_000)), proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let c = cfgOf(1, x[0])
    let open = closedBreaker().recordFailure(c, 0)
    let (probing, d) = open.allow(c, x[0])
    let reopened = probing.recordFailure(c, x[0] + x[1])
    d == dAllow and probing.recordSuccess == closedBreaker() and
      reopened.state == bsOpen and reopened.openedAtOf == x[0] + x[1])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-CIRCUITBREAKER-07
test "PAT-CIRCUITBREAKER-07 Given an open breaker, when a late success or failure arrives, then nothing changes":
  let outcome = check(pair(intIn(1, 100), intIn(0, 10_000)), proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let c = cfgOf(1, x[0])
    let open = closedBreaker().recordFailure(c, 5)
    open.recordSuccess == open and open.recordFailure(c, 5 + x[1]) == open)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-CIRCUITBREAKER-08
test "PAT-CIRCUITBREAKER-08 Given any history of events with a growing clock, when they are applied, then a closed breaker has fewer failures than the threshold and a call passes an open breaker only after the pause":
  let outcome = check(pair(intIn(1, 6), seqOf(pair(intIn(0, 8), intIn(0, 20)), 0, 60)), proc(x: (int, seq[(int, int)])): bool {.raises: [CatchableError].} =
    let c = cfgOf(x[0], 15)
    var b = closedBreaker()
    var now = 0
    for (code, dt) in x[1]:
      now += dt
      case eventOf(code)
      of evAllow:
        let before = b
        let (next, d) = b.allow(c, now)
        if d == dAllow and before.state == bsOpen and now - before.openedAtOf < c.openTicks: return false
        if d == dReject and next != before: return false
        b = next
      of evSuccess: b = b.recordSuccess
      of evFailure: b = b.recordFailure(c, now)
      if b.state == bsClosed and b.consecutiveFailures >= c.failureThreshold: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-CIRCUITBREAKER-09
test "PAT-CIRCUITBREAKER-09 Given parameters out of range, when the config is built, then each gets its own error":
  check initConfig(0, 10).error == ceThresholdNotPositive
  check initConfig(3, 0).error == ceOpenTicksNotPositive
  check initConfig(3, MaxTicks + 1).error == ceOpenTicksTooLarge
  let ok = initConfig(3, 10)
  check ok.isOk
  check ok.value.failureThreshold == 3
  check ok.value.openTicks == 10
