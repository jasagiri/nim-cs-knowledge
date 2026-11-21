import std/unittest
import propcheck
import nimcs/patterns/load_shedding

func limits(maxQueue, soft, ticks: int): Limits {.raises: [].} =
  let l = initLimits(maxQueue, soft, ticks)
  doAssert l.isOk
  l.value

func req(id: string; high: bool; deadline: int): Request {.raises: [].} =
  Request(id: id, priority: (if high: pHigh else: pLow), deadline: deadline)

const L = (maxQueue: 10, soft: 6, ticks: 3)

# SPEC: PAT-LOADSHEDDING-01
test "PAT-LOADSHEDDING-01 Given a request already decided, when it is sent again at any time and queue length, then the first decision and the same ledger come back":
  let outcome = check(pair(pair(intIn(0, 12), intIn(0, 80)), pair(pair(intIn(0, 12), intIn(0, 80)), boolean())),
      proc(x: ((int, int), ((int, int), bool))): bool {.raises: [CatchableError].} =
    let lim = limits(L.maxQueue, L.soft, L.ticks)
    let ((q1, d1), ((q2, now2), high)) = x
    let r = req("a", high, d1)
    let first = emptyLedger().decide(lim, 0, q1, r)
    let again = first.ledger.decide(lim, now2, q2, req("a", not high, 0))
    again.decision == first.decision and again.ledger == first.ledger and
      first.ledger.decidedCount == 1)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-LOADSHEDDING-02
test "PAT-LOADSHEDDING-02 Given a request, when the queue is shorter, then a request admitted at the longer queue is also admitted":
  let outcome = check(pair(pair(intIn(0, 12), intIn(0, 12)), pair(intIn(0, 90), boolean())),
      proc(x: ((int, int), (int, bool))): bool {.raises: [CatchableError].} =
    let lim = limits(L.maxQueue, L.soft, L.ticks)
    let ((a, b), (deadline, high)) = x
    let (long, short) = (max(a, b), min(a, b))
    let r = req("a", high, deadline)
    (not lim.judge(0, long, r).admitted) or lim.judge(0, short, r).admitted)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-LOADSHEDDING-03
test "PAT-LOADSHEDDING-03 Given any request, when admitted, then the queue has room and the deadline is reachable":
  let outcome = check(pair(pair(intIn(0, 12), intIn(0, 30)), pair(intIn(0, 100), boolean())),
      proc(x: ((int, int), (int, bool))): bool {.raises: [CatchableError].} =
    let lim = limits(L.maxQueue, L.soft, L.ticks)
    let ((q, now), (deadline, high)) = x
    let d = lim.judge(now, q, req("a", high, deadline))
    (not d.admitted) or
      (q < L.maxQueue and now + (q + 1) * L.ticks <= deadline and deadline > now))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-LOADSHEDDING-04
test "PAT-LOADSHEDDING-04 Given the same state, when a low and a high priority request are judged, then high is admitted whenever low is":
  let outcome = check(pair(pair(intIn(0, 12), intIn(0, 30)), intIn(0, 100)),
      proc(x: ((int, int), int)): bool {.raises: [CatchableError].} =
    let lim = limits(L.maxQueue, L.soft, L.ticks)
    let ((q, now), deadline) = x
    (not lim.judge(now, q, req("a", false, deadline)).admitted) or
      lim.judge(now, q, req("a", true, deadline)).admitted)
  checkpoint describe(outcome)
  check outcome.passed
  let lim = limits(L.maxQueue, L.soft, L.ticks)
  check lim.judge(0, L.soft, req("a", false, 1000)).reason == rLowPriorityShed
  check lim.judge(0, L.soft, req("a", true, 1000)).admitted

# SPEC: PAT-LOADSHEDDING-05
test "PAT-LOADSHEDDING-05 Given particular states, when judged, then each refusal names its own reason in the documented order":
  let lim = limits(L.maxQueue, L.soft, L.ticks)
  check lim.judge(0, 0, req("", true, 100)).reason == rNoId
  check lim.judge(5, 0, req("a", true, 5)).reason == rExpired
  check lim.judge(0, L.maxQueue, req("a", true, 1000)).reason == rQueueFull
  check lim.judge(0, 2, req("a", true, 8)).reason == rDeadlineUnreachable   # needs 3 * 3 = 9 ticks
  check lim.judge(0, 2, req("a", true, 9)).admitted
  # a full queue is reported before an unreachable deadline, an expired deadline before both
  check lim.judge(10, L.maxQueue, req("a", true, 1)).reason == rExpired
  check lim.judge(0, L.maxQueue, req("a", true, 1)).reason == rQueueFull

# SPEC: PAT-LOADSHEDDING-06
test "PAT-LOADSHEDDING-06 Given limits and a request without an id, when decided, then it is judged and never recorded; bad limits are refused":
  let lim = limits(L.maxQueue, L.soft, L.ticks)
  let r = emptyLedger().decide(lim, 0, 0, req("", true, 100))
  check r.decision.reason == rNoId
  check r.ledger.decidedCount == 0
  check initLimits(10, 11, 1).isErr
  check initLimits(10, 0, 1).isErr
  check initLimits(10, 5, 0).isErr
  check initLimits(10, 10, 1).isOk
  let known = emptyLedger().decide(lim, 0, 0, req("x", true, 100)).ledger
  check known.knows("x") and not known.knows("y")
