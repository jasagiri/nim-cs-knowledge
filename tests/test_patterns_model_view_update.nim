import std/unittest
import propcheck
import nimcs/patterns/model_view_update

func msgOf(x: (int, int)): Msg {.raises: [].} =
  case x[0]
  of 0: increment()
  of 1: decrement()
  of 2: setStep(x[1])
  of 3: undo()
  else: reset()

proc logs(): Gen[seq[(int, int)]] {.raises: [ValueError].} =
  seqOf(pair(intIn(0, 4), intIn(-3, 14)), 0, 16)

func toLog(xs: seq[(int, int)]): seq[Msg] {.raises: [].} =
  for x in xs: result.add msgOf(x)

# SPEC: PAT-MODELVIEWUPDATE-01
test "PAT-MODELVIEWUPDATE-01 Given any log, when replayed twice, then the model and the screen are identical":
  let outcome = check(logs(), proc(xs: seq[(int, int)]): bool {.raises: [CatchableError].} =
    let log = toLog(xs)
    log.replay == log.replay and log.replay.view == log.replay.view)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-MODELVIEWUPDATE-02
test "PAT-MODELVIEWUPDATE-02 Given two logs, when the second continues from the first model, then it equals replaying the join":
  let outcome = check(pair(logs(), logs()), proc(x: (seq[(int, int)], seq[(int, int)])): bool {.raises: [CatchableError].} =
    let a = toLog(x[0])
    let b = toLog(x[1])
    (a & b).replay == b.replay(a.replay))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-MODELVIEWUPDATE-03
test "PAT-MODELVIEWUPDATE-03 Given any log, when traced, then the trace has one model per message plus the start and ends at the replay":
  let outcome = check(logs(), proc(xs: seq[(int, int)]): bool {.raises: [CatchableError].} =
    let log = toLog(xs)
    let t = log.trace
    if t.len != log.len + 1 or t[0] != init() or t[^1] != log.replay: return false
    for i in 0 ..< log.len:
      if t[i + 1] != t[i].update(log[i]): return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-MODELVIEWUPDATE-04
test "PAT-MODELVIEWUPDATE-04 Given any model reached by a log, when a change is undone, then the count returns and reset is idempotent":
  let outcome = check(pair(logs(), boolean()), proc(x: (seq[(int, int)], bool)): bool {.raises: [CatchableError].} =
    let m = toLog(x[0]).replay
    let moved = m.update(if x[1]: increment() else: decrement())
    let back = moved.update(undo())
    back == m and
      m.update(reset()).update(reset()) == m.update(reset()) and
      m.update(reset()).count == 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-MODELVIEWUPDATE-05
test "PAT-MODELVIEWUPDATE-05 Given any step requested, when set, then the step stays within its range and undo with no history changes nothing":
  let outcome = check(intIn(-50, 50), proc(n: int): bool {.raises: [CatchableError].} =
    let s = init().update(setStep(n)).step
    s >= MinStep and s <= MaxStep and (n < MinStep or n > MaxStep or s == n))
  checkpoint describe(outcome)
  check outcome.passed
  check init().update(undo()) == init()
  check [increment(), increment(), setStep(3), decrement()].replay.view == "count=-1 step=3 undo=3"
