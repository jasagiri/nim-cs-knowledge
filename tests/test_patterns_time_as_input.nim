import std/[unittest, options]
import propcheck
import nimcs/fp/result
import nimcs/patterns/time_as_input

func policy(): SendPolicy {.raises: [].} =
  let p = initSendPolicy(seconds(2), seconds(5))
  doAssert p.isOk
  p.value

func at(wallMs, monoMs: int): Now {.raises: [].} =
  Now(wall: WallNs(int64(wallMs) * 1_000_000), mono: MonoNs(int64(monoMs) * 1_000_000))

# SPEC: PAT-TIMEASINPUT-01
test "PAT-TIMEASINPUT-01 Given any sender and time, when only the wall clock jumps, then the decision and the wait after a failure are unchanged":
  let gen = pair(pair(intIn(0, 20_000), intIn(0, 20_000)),
                 pair(intIn(-86_400_000, 86_400_000), boolean()))
  let outcome = check(gen, proc(x: ((int, int), (int, bool))): bool {.raises: [CatchableError].} =
    let ((changeMs, laterMs), (jumpMs, failedFirst)) = x
    let p = policy()
    var s = idle().changed(at(1_000_000, changeMs))
    let first = at(1_000_000 + changeMs, changeMs)
    if failedFirst: s = p.sent(s, first, soFailed)
    let n = at(1_000_000 + changeMs + laterMs, changeMs + laterMs)
    let jumped = n.wallJumped(int64(jumpMs) * 1_000_000)
    p.decide(s, n) == p.decide(s, jumped) and
      p.sent(s, n, soFailed).retryAt == p.sent(s, jumped, soFailed).retryAt)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TIMEASINPUT-02
test "PAT-TIMEASINPUT-02 Given a pending change and no wait, when deciding, then it sends exactly when the change is quiet old":
  let outcome = check(pair(intIn(0, 1_000_000), intIn(0, 10_000)),
      proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let (changeMs, laterMs) = x
    let s = idle().changed(at(0, changeMs))
    let d = policy().decide(s, at(0, changeMs + laterMs))
    (d == acSend) == (laterMs >= 2_000))
  checkpoint describe(outcome)
  check outcome.passed
  check policy().decide(idle(), at(0, 1_000_000)) == acWait   # nothing pending, nothing sent

# SPEC: PAT-TIMEASINPUT-03
test "PAT-TIMEASINPUT-03 Given a failed send, when deciding later, then it waits until retryAfter has passed and then sends":
  let outcome = check(intIn(0, 20_000), proc(laterMs: int): bool {.raises: [CatchableError].} =
    let p = policy()
    let failedAt = at(0, 10_000)
    let s = p.sent(idle().changed(at(0, 0)), failedAt, soFailed)
    let d = p.decide(s, failedAt.after(millis(int64(laterMs))))
    s.pending and (d == acSend) == (laterMs >= 5_000))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TIMEASINPUT-04
test "PAT-TIMEASINPUT-04 Given a send that succeeds, when a change came after it was decided, then that change stays pending; the record of the send is the wall clock of the same reading":
  let p = policy()
  let decided = at(5_000, 3_000)
  let early = idle().changed(at(0, 0))
  check p.decide(early, decided) == acSend
  check p.decide(early, decided) == p.decide(early, decided)
  check not p.sent(early, decided, soSucceeded).pending
  let late = early.changed(decided.after(millis(10)))
  check p.sent(late, decided, soSucceeded).pending
  check p.sent(late, decided, soSucceeded).retryAt.isNone
  check stamp(decided) == decided.wall

# SPEC: PAT-TIMEASINPUT-05
test "PAT-TIMEASINPUT-05 Given spans and readings, when combined, then a policy needs positive spans, adding a span and subtracting returns it, and the policy is sealed":
  check initSendPolicy(millis(0), seconds(1)).isErr
  check initSendPolicy(seconds(1), millis(-1)).isErr
  check initSendPolicy(seconds(1), seconds(1)).isOk
  let outcome = check(pair(intIn(-1_000_000, 1_000_000), intIn(0, 1_000_000)),
      proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let (t, d) = x
    (MonoNs(t) + Span(d)) - MonoNs(t) == Span(d))
  checkpoint describe(outcome)
  check outcome.passed
  check not compiles(policy().quiet)
  check not compiles(WallNs(1) - WallNs(0))          # a wait is not measured on the wall clock
  check not compiles(MonoNs(1) < WallNs(0))
  let n = sample()
  check int64(n.mono) > 0 and int64(n.wall) > 0
