import std/[unittest, options]
import propcheck
import nimcs/fp/result
import nimcs/patterns/retry_backoff

func policyOf(p: (int, (int, (int, int)))): RetryPolicy {.raises: [].} =
  let r = initPolicy(p[0], p[0] + p[1][0], p[1][1][0], p[1][1][1])
  doAssert r.isOk
  r.value

func policies(): Gen[RetryPolicy] {.raises: [ValueError].} =
  pair(intIn(1, 50), pair(intIn(0, 200), pair(intIn(1, 12), intIn(0, 100)))).map(policyOf)

func exponential(base, cap, failures: int): int {.raises: [].} =
  result = base
  for _ in 1 ..< failures: result = min(cap, result * 2)
  result = min(cap, result)

# The shell: the only place that would sleep. Here it records instead, so the test is instant.
proc retrying(p: RetryPolicy; seed: uint64; outcomes: seq[bool]; sleeps: var seq[int]): (int, bool) =
  ## Returns (calls made, succeeded). Call n succeeds when `outcomes[n - 1]` is true.
  var attempt = 1
  while true:
    if attempt <= outcomes.len and outcomes[attempt - 1]: return (attempt, true)
    let d = p.nextDelay(attempt, jitterFor(seed, attempt))
    if d.isNone: return (attempt, false)
    sleeps.add d.get
    inc attempt

func firstSuccess(outcomes: seq[bool]): int {.raises: [].} =
  ## 1-based index of the first true, or 0.
  for i, o in outcomes:
    if o: return i + 1
  0

func seeds(): Gen[uint64] {.raises: [ValueError].} =
  intIn(0, high(int)).map(proc(x: int): uint64 {.raises: [].} = uint64(x))

# SPEC: PAT-RETRYBACKOFF-01
test "PAT-RETRYBACKOFF-01 Given any policy, failure count and jitter, when a delay is asked, then it lies between min(base, cap) and cap":
  let outcome = check(pair(policies(), pair(intIn(1, 11), intIn(0, 999))), proc(x: (RetryPolicy, (int, int))): bool {.raises: [CatchableError].} =
    let p = x[0]
    if x[1][0] >= p.maxAttempts: return true
    let d = p.nextDelay(x[1][0], x[1][1])
    d.isSome and d.get <= p.capMs and d.get >= min(p.baseMs, p.capMs))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-RETRYBACKOFF-02
test "PAT-RETRYBACKOFF-02 Given any policy and any jitters, when delays are computed attempt by attempt, then they never decrease":
  let outcome = check(pair(policies(), seqOf(intIn(0, 999), 12, 12)), proc(x: (RetryPolicy, seq[int])): bool {.raises: [CatchableError].} =
    let p = x[0]
    var previous = 0
    for f in 1 ..< p.maxAttempts:
      let d = p.nextDelay(f, x[1][f - 1])
      if d.isNone or d.get < previous: return false
      previous = d.get
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-RETRYBACKOFF-03
test "PAT-RETRYBACKOFF-03 Given any policy, when failures reach maxAttempts, then it gives up and not before":
  let outcome = check(pair(policies(), intIn(1, 20)), proc(x: (RetryPolicy, int)): bool {.raises: [CatchableError].} =
    let p = x[0]
    let d = p.nextDelay(x[1], 0)
    (d.isNone) == (x[1] >= p.maxAttempts) and p.schedule(7).len == p.maxAttempts - 1)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-RETRYBACKOFF-04
test "PAT-RETRYBACKOFF-04 Given no jitter, when a delay is asked, then it is the capped doubling of the base":
  let outcome = check(pair(policies(), pair(intIn(1, 11), intIn(0, 999))), proc(x: (RetryPolicy, (int, int))): bool {.raises: [CatchableError].} =
    let p = x[0]
    if x[1][0] >= p.maxAttempts: return true
    let flat = initPolicy(p.baseMs, p.capMs, p.maxAttempts, 0)
    flat.isOk and flat.value.nextDelay(x[1][0], x[1][1]) == some(exponential(p.baseMs, p.capMs, x[1][0])) and
      p.nextDelay(x[1][0], 0) == some(exponential(p.baseMs, p.capMs, x[1][0])))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-RETRYBACKOFF-05
test "PAT-RETRYBACKOFF-05 Given a seed, when jitter and schedule are computed twice, then they are equal and jitter stays below 1000":
  let outcome = check(pair(policies(), intIn(0, 100000)), proc(x: (RetryPolicy, int)): bool {.raises: [CatchableError].} =
    let seed = uint64(x[1])
    for f in 1 .. 15:
      let j = jitterFor(seed, f)
      if j < 0 or j > 999 or j != jitterFor(seed, f): return false
    x[0].schedule(seed) == x[0].schedule(seed))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-RETRYBACKOFF-06
test "PAT-RETRYBACKOFF-06 Given parameters out of range, when the policy is built, then each gets its own error":
  check initPolicy(0, 100, 3, 10).error == peBaseNotPositive
  check initPolicy(50, 40, 3, 10).error == peCapBelowBase
  check initPolicy(1, 90_000_000, 3, 10).error == peCapTooLarge
  check initPolicy(10, 100, 0, 10).error == peNoAttempts
  check initPolicy(10, 100, 3, 101).error == peJitterOutOfRange
  check initPolicy(10, 100, 3, -1).error == peJitterOutOfRange

# SPEC: PAT-RETRYBACKOFF-06
test "PAT-RETRYBACKOFF-06 Given valid parameters, when the policy is built, then it reports exactly them":
  let outcome = check(pair(intIn(1, 50), pair(intIn(0, 200), pair(intIn(1, 12), intIn(0, 100)))),
    proc(x: (int, (int, (int, int)))): bool {.raises: [CatchableError].} =
      let r = initPolicy(x[0], x[0] + x[1][0], x[1][1][0], x[1][1][1])
      r.isOk and r.value.baseMs == x[0] and r.value.capMs == x[0] + x[1][0] and
        r.value.maxAttempts == x[1][1][0] and r.value.jitterPct == x[1][1][1])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-RETRYBACKOFF-07
test "PAT-RETRYBACKOFF-07 Given any pattern of successes and failures, when the policy is simulated, then calls, success and sleeps follow from the first success and the schedule":
  let outcome = check(pair(policies(), pair(seeds(), seqOf(boolean(), 0, 20))), proc(x: (RetryPolicy, (uint64, seq[bool]))): bool {.raises: [CatchableError].} =
    let p = x[0]
    let first = firstSuccess(x[1][1])
    let t = p.simulate(x[1][0], x[1][1])
    let planned = p.schedule(x[1][0])
    let expectCalls = if first > 0 and first <= p.maxAttempts: first else: p.maxAttempts
    let expectOk = first > 0 and first <= p.maxAttempts
    t.calls == expectCalls and t.succeeded == expectOk and t.sleeps == planned[0 ..< expectCalls - 1])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-RETRYBACKOFF-07
test "PAT-RETRYBACKOFF-07 Given the same pattern, when an imperative shell retries, then it makes the calls and sleeps the waits the simulation predicts":
  let outcome = check(pair(policies(), pair(seeds(), seqOf(boolean(), 0, 20))), proc(x: (RetryPolicy, (uint64, seq[bool]))): bool {.raises: [CatchableError].} =
    var sleeps: seq[int]
    let (calls, ok) = retrying(x[0], x[1][0], x[1][1], sleeps)
    let t = x[0].simulate(x[1][0], x[1][1])
    t.calls == calls and t.succeeded == ok and t.sleeps == sleeps)
  checkpoint describe(outcome)
  check outcome.passed
