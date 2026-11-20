## Time as input: two clocks kept apart by type, read once at the edge, and no zero time.
##
## A program asks the time for two different reasons. To record or show a moment (a file's
## mtime, a log line, the name of a backup) it needs the wall clock, which can jump when NTP or a
## person sets it. To wait (a quiet period, a retry delay, a deadline) it needs the monotonic
## clock, which never jumps and means nothing outside the process. Here they are distinct types:
## `WallNs` and `MonoNs`, and `Span` for a length of time. Only two `MonoNs` subtract to a `Span`,
## and only a `Span` is added to a `MonoNs`, so a wait measured on the wall clock does not compile.
##
## The edge reads both clocks once, as one `Now`, and passes it in. Everything that decides is a
## `func` of that value: the compiler refuses a clock read inside it, a test builds any `Now` it
## likes (including one where only the wall clock jumped), and the same inputs give the same
## answer. A time that has not happened yet is `none`, never 0: a 0 wall time shows as 1970, and
## a 0 monotonic time is the moment the machine booted, not "long ago".
##
## The example decides when to send local changes: once the last change is `quiet` old, and not
## before the wait after a failed send (`retryAfter`) is over.

import std/[options, times, monotimes]
import nimcs/fp/result

type
  WallNs* = distinct int64
    ## Wall clock: nanoseconds since the Unix epoch. To record and show; may jump.
  MonoNs* = distinct int64
    ## Monotonic clock: nanoseconds from an origin of the process's choosing. To wait; never jumps.
  Span* = distinct int64
    ## A length of time in nanoseconds: the difference of two `MonoNs`.

  Now* = object
    ## Both clocks read at one moment, at the edge.
    wall*: WallNs
    mono*: MonoNs

  SendPolicy* {.requiresInit.} = object
    ## Sealed: only `initSendPolicy` builds one, so both spans are positive.
    quiet: Span
    retryAfter: Span

  PolicyError* = enum
    peQuietNotPositive, peRetryNotPositive

  Sender* = object
    ## What the decision remembers, as plain data.
    pending*: bool                ## local changes not yet sent
    lastChange*: Option[MonoNs]   ## none: no change since the sender began
    retryAt*: Option[MonoNs]      ## the end of the wait after a failure; none: no wait

  Action* = enum
    acWait, acSend

  SendOutcome* = enum
    soSucceeded, soFailed

func `==`*(a, b: WallNs): bool {.borrow.}
func `<`*(a, b: WallNs): bool {.borrow.}
func `<=`*(a, b: WallNs): bool {.borrow.}
func `==`*(a, b: MonoNs): bool {.borrow.}
func `<`*(a, b: MonoNs): bool {.borrow.}
func `<=`*(a, b: MonoNs): bool {.borrow.}
func `==`*(a, b: Span): bool {.borrow.}
func `<`*(a, b: Span): bool {.borrow.}
func `<=`*(a, b: Span): bool {.borrow.}

func `-`*(later, earlier: MonoNs): Span {.raises: [].} =
  ## How long passed between two readings of the monotonic clock.
  Span(int64(later) - int64(earlier))

func `+`*(t: MonoNs; d: Span): MonoNs {.raises: [].} =
  ## The monotonic time `d` after `t`.
  MonoNs(int64(t) + int64(d))

func millis*(n: int64): Span {.raises: [].} = Span(n * 1_000_000)

func seconds*(n: int64): Span {.raises: [].} = Span(n * 1_000_000_000)

func after*(n: Now; d: Span): Now {.raises: [].} =
  ## A test's clock moved on by `d`: both clocks advance together.
  Now(wall: WallNs(int64(n.wall) + int64(d)), mono: n.mono + d)

func wallJumped*(n: Now; byNs: int64): Now {.raises: [].} =
  ## A test's clock where only the wall clock was set (NTP, by hand); the monotonic one did not move.
  Now(wall: WallNs(int64(n.wall) + byNs), mono: n.mono)

func initSendPolicy*(quiet, retryAfter: Span): Result[SendPolicy, PolicyError] {.raises: [].} =
  ## Both spans must be positive.
  if int64(quiet) <= 0: return err(SendPolicy, peQuietNotPositive)
  if int64(retryAfter) <= 0: return err(SendPolicy, peRetryNotPositive)
  ok(SendPolicy(quiet: quiet, retryAfter: retryAfter), PolicyError)

func idle*(): Sender {.raises: [].} =
  ## A sender with nothing to send and no wait.
  Sender(pending: false, lastChange: none(MonoNs), retryAt: none(MonoNs))

func changed*(s: Sender; now: Now): Sender {.raises: [].} =
  ## A local change was made at `now`.
  result = s
  result.pending = true
  result.lastChange = some(now.mono)

func decide*(p: SendPolicy; s: Sender; now: Now): Action {.raises: [].} =
  ## Send when there is something to send, the last change is `quiet` old and no wait after a
  ## failure is running. Only `now.mono` is read: a jump of the wall clock changes nothing.
  if not s.pending: return acWait
  if s.retryAt.isSome and now.mono < s.retryAt.get: return acWait
  if s.lastChange.isSome and now.mono - s.lastChange.get < p.quiet: return acWait
  acSend

func sent*(p: SendPolicy; s: Sender; now: Now; outcome: SendOutcome): Sender {.raises: [].} =
  ## The send decided at `now` ended. Success clears what was pending, except a change made after
  ## `now` (it was not in the send); a failure keeps everything and waits `retryAfter`.
  result = s
  if outcome == soSucceeded:
    result.pending = s.lastChange.isSome and now.mono < s.lastChange.get
    result.retryAt = none(MonoNs)
  else:
    result.retryAt = some(now.mono + p.retryAfter)

func stamp*(now: Now): WallNs {.raises: [].} =
  ## The time to record for what was sent at `now`: the wall clock of the same reading.
  now.wall

proc sample*(): Now {.raises: [].} =
  ## The edge: reads both clocks, once, at one moment. The only routine here that is not a
  ## `func`; the shell calls it and hands the value to everything above.
  let w = getTime()
  Now(wall: WallNs(w.toUnix * 1_000_000_000 + int64(w.nanosecond)), mono: MonoNs(getMonoTime().ticks))
