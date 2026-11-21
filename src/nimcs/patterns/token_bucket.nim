## Token bucket: a rate limiter whose refill is computed from the time passed in.
##
## A bucket holds up to `capacity` tokens and gains `refillTokens` tokens every `refillTicks` ticks;
## a request takes tokens or is refused. A burst of up to `capacity` goes through at once, and in
## the long run the rate cannot exceed the refill rate. There is no timer: the bucket remembers the
## tick of its last update, and every operation takes `now` as an argument and computes the refill
## from the elapsed ticks (see `time_as_input`). To keep that computation exact without fractions,
## the amount is stored in units of 1/`refillTicks` token: each elapsed tick adds `refillTokens`
## units and a token costs `refillTicks` units, so no rounding error accumulates however the
## elapsed time is split between calls. `tryTake` returns the new bucket and whether the tokens
## were granted. Use it to limit calls per client or per dependency; use `bulkhead` to limit calls
## in flight instead of calls per time. A clock that goes backwards is treated as no time passing.
## Parameters are bounded (1_000_000) so that no product can overflow.

import nimcs/fp/result
export result

const MaxParam* = 1_000_000

type
  BucketConfig* = object
    capacity: int
    refillTokens: int
    refillTicks: int

  ConfigError* = enum
    ceCapacityOutOfRange, ceRefillTokensOutOfRange, ceRefillTicksOutOfRange

  Bucket* = object
    cfg: BucketConfig
    units: int       ## stored amount, in 1/refillTicks tokens; 0 .. capacity * refillTicks
    updated: int     ## the latest tick seen

func capacity*(c: BucketConfig): int {.raises: [].} = c.capacity
func refillTokens*(c: BucketConfig): int {.raises: [].} = c.refillTokens
func refillTicks*(c: BucketConfig): int {.raises: [].} = c.refillTicks

func initConfig*(capacity, refillTokens, refillTicks: int): Result[BucketConfig, ConfigError] {.raises: [].} =
  ## `refillTokens` tokens are added every `refillTicks` ticks, up to `capacity`. Each parameter
  ## must lie in 1 .. `MaxParam`.
  if capacity < 1 or capacity > MaxParam: err(BucketConfig, ceCapacityOutOfRange)
  elif refillTokens < 1 or refillTokens > MaxParam: err(BucketConfig, ceRefillTokensOutOfRange)
  elif refillTicks < 1 or refillTicks > MaxParam: err(BucketConfig, ceRefillTicksOutOfRange)
  else: ok(BucketConfig(capacity: capacity, refillTokens: refillTokens, refillTicks: refillTicks), ConfigError)

func `==`*(a, b: Bucket): bool {.raises: [].} =
  a.cfg == b.cfg and a.units == b.units and a.updated == b.updated

func config*(b: Bucket): BucketConfig {.raises: [].} = b.cfg

func fullBucket*(cfg: BucketConfig; now: int): Bucket {.raises: [].} =
  ## A bucket that starts full at tick `now`.
  Bucket(cfg: cfg, units: cfg.capacity * cfg.refillTicks, updated: now)

func refill*(b: Bucket; now: int): Bucket {.raises: [].} =
  ## The bucket as it is at `now`: elapsed ticks add units, capped at the capacity. A `now` that
  ## is not after the last update changes nothing. `refill(refill(b, t1), t2) == refill(b, t2)`
  ## for t1 <= t2, so asking at intermediate times never changes the result (PAT-TOKENBUCKET-05).
  if now <= b.updated:
    return b
  let capUnits = b.cfg.capacity * b.cfg.refillTicks
  let elapsed = now - b.updated
  let missing = capUnits - b.units
  # Ticks needed to fill the gap; comparing first keeps `elapsed * refillTokens` from overflowing.
  let ticksToFull = (missing + b.cfg.refillTokens - 1) div b.cfg.refillTokens
  let units = if elapsed >= ticksToFull: capUnits else: b.units + elapsed * b.cfg.refillTokens
  Bucket(cfg: b.cfg, units: units, updated: now)

func available*(b: Bucket; now: int): int {.raises: [].} =
  ## Whole tokens that could be taken at `now`.
  b.refill(now).units div b.cfg.refillTicks

func tryTake*(b: Bucket; now: int; n: Positive): tuple[bucket: Bucket, granted: bool] {.raises: [].} =
  ## Take `n` tokens at `now` if that many are available. On refusal the returned bucket is the
  ## refilled one with nothing taken, so the refill already computed is not lost.
  let r = b.refill(now)
  if n > r.cfg.capacity or r.units < n * r.cfg.refillTicks:
    (r, false)
  else:
    (Bucket(cfg: r.cfg, units: r.units - n * r.cfg.refillTicks, updated: r.updated), true)
