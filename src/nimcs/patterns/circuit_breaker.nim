## Circuit breaker: stop calling a dependency that keeps failing, and probe it again after a pause.
##
## Calling a dead dependency costs every caller a timeout and keeps the dependency under load while
## it tries to recover. A breaker watches the outcomes and has three states: closed (calls pass,
## consecutive failures are counted), open (calls are refused until a pause has passed) and half-open
## (one probe call passes; its outcome decides whether to close or to open again). The breaker is an
## object variant, so the data that only one state needs (a failure count, the time of opening, the
## probe flag) exists only in that state. Every transition is a pure function that returns the new
## breaker; the clock is an argument (`now`, in ticks), never read here (see `time_as_input`).
## `allow` also returns a `Decision`; a refusal returns the breaker unchanged. Use it around calls to
## a remote service, and pair it with `retry_backoff`: backoff spaces out the retries of one caller,
## the breaker stops all callers once the failures are persistent. Ticks must be non-negative and
## below 2^52, so that adding the pause to the time of opening cannot overflow.

import nimcs/fp/result
export result

const MaxTicks* = 4_503_599_627_370_496  ## 2^52

type
  BreakerState* = enum
    bsClosed, bsOpen, bsHalfOpen

  Decision* = enum
    dAllow, dReject

  BreakerConfig* = object
    failureThreshold: int
    openTicks: int

  ConfigError* = enum
    ceThresholdNotPositive, ceOpenTicksNotPositive, ceOpenTicksTooLarge

  Breaker* = object
    case state: BreakerState
    of bsClosed:
      failures: int      ## consecutive failures so far
    of bsOpen:
      openedAt: int
    of bsHalfOpen:
      probing: bool      ## a probe call has been admitted and has not reported yet

func failureThreshold*(c: BreakerConfig): int {.raises: [].} = c.failureThreshold
func openTicks*(c: BreakerConfig): int {.raises: [].} = c.openTicks

func initConfig*(failureThreshold, openTicks: int): Result[BreakerConfig, ConfigError] {.raises: [].} =
  ## `failureThreshold` consecutive failures open the breaker; it stays open for `openTicks`.
  if failureThreshold < 1: err(BreakerConfig, ceThresholdNotPositive)
  elif openTicks < 1: err(BreakerConfig, ceOpenTicksNotPositive)
  elif openTicks > MaxTicks: err(BreakerConfig, ceOpenTicksTooLarge)
  else: ok(BreakerConfig(failureThreshold: failureThreshold, openTicks: openTicks), ConfigError)

func closedBreaker*(): Breaker {.raises: [].} = Breaker(state: bsClosed, failures: 0)

func state*(b: Breaker): BreakerState {.raises: [].} = b.state

func consecutiveFailures*(b: Breaker): int {.raises: [].} =
  ## The failures counted while closed; 0 in the other states.
  case b.state
  of bsClosed: b.failures
  of bsOpen, bsHalfOpen: 0

func `==`*(a, b: Breaker): bool {.raises: [].} =
  if a.state != b.state: return false
  case a.state
  of bsClosed: a.failures == b.failures
  of bsOpen: a.openedAt == b.openedAt
  of bsHalfOpen: a.probing == b.probing

func openedAtOf*(b: Breaker): int {.raises: [].} =
  ## The tick at which an open breaker opened; -1 when it is not open.
  case b.state
  of bsOpen: b.openedAt
  of bsClosed, bsHalfOpen: -1

func allow*(b: Breaker; c: BreakerConfig; now: int): tuple[breaker: Breaker, decision: Decision] {.raises: [].} =
  ## May a call start at `now`? Closed: yes. Open: no, until `openTicks` have passed since opening;
  ## then the breaker becomes half-open and this call is the probe. Half-open: yes only for the
  ## first call (the probe), no for the others while the probe has not reported. A refusal returns
  ## the breaker unchanged. A `now` earlier than the time of opening counts as "not yet".
  case b.state
  of bsClosed:
    (b, dAllow)
  of bsOpen:
    if now - b.openedAt >= c.openTicks:
      (Breaker(state: bsHalfOpen, probing: true), dAllow)
    else:
      (b, dReject)
  of bsHalfOpen:
    if b.probing: (b, dReject)
    else: (Breaker(state: bsHalfOpen, probing: true), dAllow)

func recordSuccess*(b: Breaker): Breaker {.raises: [].} =
  ## A call reported success. Closed: the failure count restarts. Half-open: the probe succeeded,
  ## close. Open: a late report from a call started before opening; ignored.
  case b.state
  of bsClosed: closedBreaker()
  of bsHalfOpen: closedBreaker()
  of bsOpen: b

func recordFailure*(b: Breaker; c: BreakerConfig; now: int): Breaker {.raises: [].} =
  ## A call reported failure at `now`. Closed: count it, and open when the count reaches the
  ## threshold. Half-open: the probe failed, open again from `now`. Open: ignored, so a late
  ## report does not push the reopening time further away.
  case b.state
  of bsClosed:
    if b.failures + 1 >= c.failureThreshold: Breaker(state: bsOpen, openedAt: now)
    else: Breaker(state: bsClosed, failures: b.failures + 1)
  of bsHalfOpen:
    Breaker(state: bsOpen, openedAt: now)
  of bsOpen:
    b
