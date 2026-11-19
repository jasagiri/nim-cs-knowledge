# Retry with backoff

## Intent
After a failed call, wait before trying again; wait longer after each failure, up to a cap; add a little jitter so clients that failed together do not retry together. Make the policy plain data and the schedule a pure function of it: given the failure count and a jitter sample, return the next delay or give up. The loop that sleeps and calls the operation is the imperative shell.

## Use when / avoid when
- Use for calls to flaky dependencies: networks, rate-limited APIs, lock contention.
- Use when the schedule must be tested without sleeping and without a random source.
- Avoid retrying operations that are not idempotent unless a key makes them so (`idempotent_command.md`).
- Avoid unbounded retries; the policy always has a finite `maxAttempts`.

## Nim shape
`src/nimcs/patterns/retry_backoff.nim`. `initPolicy(baseMs, capMs, maxAttempts, jitterPct)` is the smart constructor returning `Result[RetryPolicy, PolicyError]`. `nextDelay(policy, failures, jitter)` returns `Option[int]` (none means give up). The jitter is an argument, a `Permille` (0..999), produced from a seed by `jitterFor`; `schedule(policy, seed)` lists every wait. The step doubles up to the cap, the jitter adds at most `jitterPct` percent of the step, and the sum is cut at the cap.

```nim
import std/options
import nimcs/fp/result
import nimcs/patterns/retry_backoff

let policy = initPolicy(100, 1_000, 5, 0).value
var delays: seq[int]
for failures in 1 .. 4:
  delays.add policy.nextDelay(failures, 0).get
doAssert delays == @[100, 200, 400, 800]
doAssert policy.nextDelay(5, 0).isNone
doAssert policy.schedule(1) == delays
```

The shell is the only code that waits; here the sleeper is a parameter, so a test can record instead of sleeping.

```nim
import std/options
import nimcs/fp/result
import nimcs/patterns/retry_backoff

proc callWithRetry(policy: RetryPolicy; seed: uint64; flaky: proc(n: int): bool;
                   sleep: proc(ms: int)): bool =
  var attempt = 1
  while true:
    if flaky(attempt): return true
    let wait = policy.nextDelay(attempt, jitterFor(seed, attempt))
    if wait.isNone: return false
    sleep(wait.get)
    inc attempt

var slept: seq[int]
let policy = initPolicy(100, 1_000, 3, 0).value
doAssert callWithRetry(policy, 7, proc(n: int): bool = n == 3, proc(ms: int) = slept.add ms)
doAssert slept == @[100, 200]
```

## Laws and invariants
Why this is testable: nothing in `nextDelay` touches a clock or a random generator, so delays are checked for any policy and any jitter values, not for the few that happened to occur.
- Every delay lies between `min(base, cap)` and the cap (PAT-RETRYBACKOFF-01).
- Delays never decrease with the failure count, whatever the jitter values (PAT-RETRYBACKOFF-02); this holds because the jitter adds at most one step.
- It gives up exactly when failures reach `maxAttempts`; the schedule has `maxAttempts - 1` waits (PAT-RETRYBACKOFF-03).
- With no jitter the delay is the base doubled per failure, cut at the cap (PAT-RETRYBACKOFF-04).
- `jitterFor` is deterministic and stays in 0..999; a schedule is reproducible from its seed (PAT-RETRYBACKOFF-05).
- `initPolicy` gives each out-of-range parameter its own error (PAT-RETRYBACKOFF-06).
- The whole loop is also a pure function, `simulate(policy, seed, outcomes)`: for any seed and any pattern of outcomes it makes as many calls as the first success (capped at `maxAttempts`), reports success only within the cap, and sleeps a prefix of the schedule; the imperative shell above is tested to make the same calls and sleep the same waits (PAT-RETRYBACKOFF-07).

## Complexity
`nextDelay` is O(min(failures, log(cap/base))) because the doubling stops at the cap; `schedule` is O(maxAttempts) calls of it. Space is O(1) per delay and O(maxAttempts) for a schedule.

## Pitfalls
Drawing the jitter and sleeping inside the function that computes the delay makes the schedule unrepeatable and untestable.

```nim bad
proc nextDelay(attempt: int): int =
  let jitter = rand(1000)
  result = min(cap, base shl attempt) + jitter
  sleep(result)
```

Take the jitter as an argument and return the delay; the shell sleeps:

```nim
import std/options
import nimcs/fp/result
import nimcs/patterns/retry_backoff

let p = initPolicy(50, 400, 4, 50).value
doAssert p.nextDelay(1, 999).get <= 400
doAssert p.nextDelay(1, 999) == p.nextDelay(1, 999)
```

Also validate the policy once: a cap below the base or a jitter over 100 percent breaks the monotonicity law, which is why `initPolicy` refuses them instead of clamping.

## Related
- `idempotent_command.md` (what makes a retry safe)
- `dependency_record.md` (injecting the sleeper and the operation)
- `functional_core.md` (the same core/shell split)

## Sources

None in the catalog: no table of contents among the 450 core sources examined so far (catalog/concepts.json) names this concept.
