import std/unittest
import propcheck
import nimcs/patterns/singleton

# SPEC: GOF-SINGLETON-01
test "GOF-SINGLETON-01 Given the default settings, when a changed copy is derived, then the constant is unchanged":
  let outcome = check(intIn(-10, 10), proc(n: int): bool {.raises: [CatchableError].} =
    let changed = DefaultSettings.withRetries(n)
    changed.retries == n and DefaultSettings.retries == 3 and
      DefaultSettings.label == "default")
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-SINGLETON-02
test "GOF-SINGLETON-02 Given a fixed clock, when stamping, then the result is deterministic and holds time and message":
  let outcome = check(pair(intIn(0, 100000), stringOf("abc ", 0, 8)), proc(p: (int, string)): bool {.raises: [CatchableError].} =
    let c = fixedClock(int64(p[0]))
    stamp(c, p[1]) == stamp(c, p[1]) and stamp(c, p[1]) == $p[0] & ": " & p[1])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-SINGLETON-03
test "GOF-SINGLETON-03 Given two clocks, when stamping the same message, then results differ exactly when the times differ":
  let outcome = check(pair(intIn(0, 20), intIn(0, 20)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    let a = fixedClock(int64(p[0]))
    let b = fixedClock(int64(p[1]))
    (stamp(a, "m") == stamp(b, "m")) == (p[0] == p[1]))
  checkpoint describe(outcome)
  check outcome.passed
