## Retry with backoff: the policy is data, `nextDelay` is a pure function, only the sleeping is effect.
##
## After the n-th failure a client waits before trying again; the wait grows geometrically up to
## a cap, and a jitter spreads out clients that failed together. Here the policy is a validated
## record and `nextDelay(failures, jitter)` is a function of it: it returns the delay in
## milliseconds, or `none` when the attempts are used up. The jitter is an argument (a per-mille
## value), derived from a seed by `jitterFor`, so the schedule is reproducible and testable
## without a clock or a random source. The loop that calls the operation and actually sleeps is
## the imperative shell and lives with the caller. Use it for any retried call to a flaky
## dependency.

import std/options
import nimcs/fp/result

const MaxCapMs* = 86_400_000  ## one day; keeps every intermediate product far below int range

type
  Permille* = range[0 .. 999]
    ## A jitter sample: the fraction of the extra delay used, in thousandths.

  RetryPolicy* = object
    baseMs: int
    capMs: int
    maxAttempts: int
    jitterPct: int

  PolicyError* = enum
    peBaseNotPositive, peCapBelowBase, peCapTooLarge, peNoAttempts, peJitterOutOfRange

func baseMs*(p: RetryPolicy): int {.raises: [].} = p.baseMs
func capMs*(p: RetryPolicy): int {.raises: [].} = p.capMs
func maxAttempts*(p: RetryPolicy): int {.raises: [].} = p.maxAttempts
func jitterPct*(p: RetryPolicy): int {.raises: [].} = p.jitterPct

func initPolicy*(baseMs, capMs, maxAttempts, jitterPct: int): Result[RetryPolicy, PolicyError] {.raises: [].} =
  ## `baseMs` is the delay after the first failure; `maxAttempts` counts calls of the operation
  ## (so there are `maxAttempts - 1` waits); `jitterPct` (0..100) is how much of the step may be
  ## added on top. The first violated rule, in the order of the `PolicyError` values, is reported.
  if baseMs < 1: err(RetryPolicy, peBaseNotPositive)
  elif capMs < baseMs: err(RetryPolicy, peCapBelowBase)
  elif capMs > MaxCapMs: err(RetryPolicy, peCapTooLarge)
  elif maxAttempts < 1: err(RetryPolicy, peNoAttempts)
  elif jitterPct < 0 or jitterPct > 100: err(RetryPolicy, peJitterOutOfRange)
  else: ok(RetryPolicy(baseMs: baseMs, capMs: capMs, maxAttempts: maxAttempts, jitterPct: jitterPct), PolicyError)

func nextDelay*(p: RetryPolicy; failures: Positive; jitter: Permille): Option[int] {.raises: [].} =
  ## The wait after the `failures`-th failure, or `none` when `failures >= maxAttempts` (give up).
  ## The step doubles from the base up to the cap; the jitter adds at most `jitterPct` percent of
  ## the step; the sum is cut at the cap. Because the extra is at most the step, delays never
  ## decrease as `failures` grows, whatever the jitter values (PAT-RETRYBACKOFF-02).
  if failures >= p.maxAttempts:
    return none(int)
  var step = p.baseMs
  for _ in 1 ..< failures:
    if step >= p.capMs: break
    step = min(p.capMs, step * 2)
  let extra = step * p.jitterPct * jitter div 100_000
  some(min(p.capMs, step + extra))

func jitterFor*(seed: uint64; failures: Positive): Permille {.raises: [].} =
  ## A reproducible jitter sample for the given seed and failure count (a splitmix64 mix).
  var z = seed + uint64(failures) * 0x9E3779B97F4A7C15'u64
  z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9'u64
  z = (z xor (z shr 27)) * 0x94D049BB133111EB'u64
  z = z xor (z shr 31)
  Permille(int(z mod 1000'u64))

func schedule*(p: RetryPolicy; seed: uint64): seq[int] {.raises: [].} =
  ## Every wait the policy would produce for this seed, in order: `maxAttempts - 1` of them.
  for failures in 1 ..< p.maxAttempts:
    let d = p.nextDelay(failures, jitterFor(seed, failures))
    if d.isSome: result.add d.get

type
  RetryTrace* = object
    ## What a retry loop does for a given pattern of outcomes.
    calls*: int
    succeeded*: bool
    sleeps*: seq[int]

func simulate*(p: RetryPolicy; seed: uint64; outcomes: openArray[bool]): RetryTrace {.raises: [].} =
  ## The retry loop as a pure function. Call n succeeds when `outcomes[n - 1]` is true; a call
  ## beyond the end of `outcomes` fails. After each failure the loop waits `nextDelay` with the
  ## seed's jitter, and stops when the policy gives up. An imperative shell that really calls
  ## the operation and sleeps must make the same calls and waits.
  var attempt = 1
  while true:
    if attempt <= outcomes.len and outcomes[attempt - 1]:
      return RetryTrace(calls: attempt, succeeded: true, sleeps: result.sleeps)
    let d = p.nextDelay(attempt, jitterFor(seed, attempt))
    if d.isNone:
      return RetryTrace(calls: attempt, succeeded: false, sleeps: result.sleeps)
    result.sleeps.add d.get
    inc attempt
