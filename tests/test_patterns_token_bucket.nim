import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/patterns/token_bucket

func cfgOf(capacity, tokens, ticks: int): BucketConfig {.raises: [].} =
  let r = initConfig(capacity, tokens, ticks)
  doAssert r.isOk
  r.value

func configs(): Gen[BucketConfig] {.raises: [ValueError].} =
  pair(intIn(1, 20), pair(intIn(1, 10), intIn(1, 10))).map(proc(x: (int, (int, int))): BucketConfig {.raises: [].} =
    cfgOf(x[0], x[1][0], x[1][1]))

# SPEC: PAT-TOKENBUCKET-01
test "PAT-TOKENBUCKET-01 Given a new bucket, when its tokens are counted at the start, then it holds exactly its capacity":
  let outcome = check(pair(configs(), intIn(0, 100_000)), proc(x: (BucketConfig, int)): bool {.raises: [CatchableError].} =
    let b = fullBucket(x[0], x[1])
    b.available(x[1]) == x[0].capacity and b.config == x[0])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TOKENBUCKET-02
test "PAT-TOKENBUCKET-02 Given any bucket, when n tokens are asked at one time, then a grant takes exactly n and a refusal takes none":
  let outcome = check(pair(configs(), pair(intIn(0, 30), pair(intIn(1, 25), intIn(0, 40)))), proc(x: (BucketConfig, (int, (int, int)))): bool {.raises: [CatchableError].} =
    let b = fullBucket(x[0], 0)
    let (drained, _) = b.tryTake(0, 1)
    let t = x[1][0]
    let n = x[1][1][0]
    let now = t + x[1][1][1]
    let before = drained.available(now)
    let (after, granted) = drained.tryTake(now, n)
    if granted: after.available(now) == before - n and n <= before
    else: after.available(now) == before and (n > before))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TOKENBUCKET-03
test "PAT-TOKENBUCKET-03 Given any requests with a growing clock, when they are granted, then the total never exceeds capacity plus rate times elapsed":
  let outcome = check(pair(configs(), seqOf(pair(intIn(0, 15), intIn(1, 8)), 0, 60)), proc(x: (BucketConfig, seq[(int, int)])): bool {.raises: [CatchableError].} =
    let c = x[0]
    var b = fullBucket(c, 0)
    var now = 0
    var total = 0
    for (dt, n) in x[1]:
      now += dt
      let (next, granted) = b.tryTake(now, n)
      b = next
      if granted: total += n
      if total > c.capacity + c.refillTokens * now div c.refillTicks: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TOKENBUCKET-03
test "PAT-TOKENBUCKET-03 Given a greedy client that asks for one token every tick, when the bucket is observed, then it gets close to the bound":
  let c = cfgOf(5, 1, 2)
  var b = fullBucket(c, 0)
  var total = 0
  for now in 0 .. 99:
    let (next, granted) = b.tryTake(now, 1)
    b = next
    if granted: inc total
  check total == 5 + 99 div 2

# SPEC: PAT-TOKENBUCKET-04
test "PAT-TOKENBUCKET-04 Given any history, when tokens are counted, then they never exceed the capacity":
  let outcome = check(pair(configs(), seqOf(pair(intIn(0, 200), intIn(1, 30)), 0, 40)), proc(x: (BucketConfig, seq[(int, int)])): bool {.raises: [CatchableError].} =
    var b = fullBucket(x[0], 0)
    var now = 0
    for (dt, n) in x[1]:
      now += dt
      b = b.tryTake(now, n).bucket
      if b.available(now) > x[0].capacity or b.available(now) < 0: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TOKENBUCKET-05
test "PAT-TOKENBUCKET-05 Given a used bucket, when it is refilled at an intermediate time first, then the result equals refilling directly":
  let outcome = check(pair(configs(), pair(intIn(1, 30), pair(intIn(0, 50), intIn(0, 50)))), proc(x: (BucketConfig, (int, (int, int)))): bool {.raises: [CatchableError].} =
    let b = fullBucket(x[0], 0).tryTake(0, x[1][0] mod x[0].capacity + 1).bucket
    let t1 = x[1][1][0]
    let t2 = t1 + x[1][1][1]
    b.refill(t1).refill(t2) == b.refill(t2) and b.refill(t2).refill(t2) == b.refill(t2))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TOKENBUCKET-06
test "PAT-TOKENBUCKET-06 Given a drained bucket, when enough time has passed, then it is full again and not before":
  let outcome = check(configs(), proc(c: BucketConfig): bool {.raises: [CatchableError].} =
    let drained = fullBucket(c, 0).tryTake(0, c.capacity).bucket
    # ticks needed to refill everything: ceil(capacity * refillTicks / refillTokens)
    let need = (c.capacity * c.refillTicks + c.refillTokens - 1) div c.refillTokens
    drained.available(0) == 0 and drained.available(need) == c.capacity and
      (need == 0 or drained.available(need - 1) < c.capacity) and drained.available(need + 1000) == c.capacity)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TOKENBUCKET-07
test "PAT-TOKENBUCKET-07 Given a clock that goes backwards, when tokens are asked, then no tokens are created":
  let c = cfgOf(3, 1, 1)
  let (b, g1) = fullBucket(c, 100).tryTake(100, 3)
  check g1
  let (b2, g2) = b.tryTake(10, 1)
  check not g2
  check b2 == b
  check b.available(5) == 0

# SPEC: PAT-TOKENBUCKET-07
test "PAT-TOKENBUCKET-07 Given a request larger than the capacity, when asked, then it is refused whatever the time":
  let c = cfgOf(3, 3, 1)
  let (b, g) = fullBucket(c, 0).tryTake(1_000_000_000, 4)
  check not g
  check b.available(1_000_000_000) == 3

# SPEC: PAT-TOKENBUCKET-08
test "PAT-TOKENBUCKET-08 Given parameters out of range, when the config is built, then each gets its own error":
  check initConfig(0, 1, 1).error == ceCapacityOutOfRange
  check initConfig(MaxParam + 1, 1, 1).error == ceCapacityOutOfRange
  check initConfig(1, 0, 1).error == ceRefillTokensOutOfRange
  check initConfig(1, MaxParam + 1, 1).error == ceRefillTokensOutOfRange
  check initConfig(1, 1, 0).error == ceRefillTicksOutOfRange
  let huge = initConfig(MaxParam, MaxParam, 1)
  check huge.isOk
  check fullBucket(huge.value, 0).available(high(int) div 2) == MaxParam

# SPEC: PAT-TOKENBUCKET-08
test "PAT-TOKENBUCKET-08 Given parameters at and just beyond 1_000_000, when the config is built, then 1_000_000 is accepted and one more is refused":
  check initConfig(1_000_000, 1, 1).isOk
  check initConfig(1, 1_000_000, 1).isOk
  check initConfig(1, 1, 1_000_000).isOk
  check initConfig(1_000_001, 1, 1).error == ceCapacityOutOfRange
  check initConfig(1, 1_000_001, 1).error == ceRefillTokensOutOfRange
  check initConfig(1, 1, 1_000_001).error == ceRefillTicksOutOfRange

# SPEC: PAT-TOKENBUCKET-01
test "PAT-TOKENBUCKET-01 Given buckets that differ in one part, when they are compared, then they are unequal":
  let c = cfgOf(2, 1, 1)
  let b = fullBucket(c, 0)
  check b == fullBucket(c, 0)
  check b != fullBucket(c, 1)                 # updated only
  check b != fullBucket(cfgOf(2, 5, 1), 0)    # configuration only: same units, same time
  check b != b.tryTake(0, 1).bucket           # units only
