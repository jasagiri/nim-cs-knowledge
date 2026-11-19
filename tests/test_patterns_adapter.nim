import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/patterns/adapter

# SPEC: GOF-ADAPTER-01
test "GOF-ADAPTER-01 Given any minute of the day, when formatted and parsed, then it round-trips":
  let outcome = check(intIn(0, 1439), proc(m: int): bool {.raises: [CatchableError].} =
    let r = fromLegacy(toLegacy(Minutes(m)))
    r.isOk and r.value == Minutes(m))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-ADAPTER-01
test "GOF-ADAPTER-01 Given a known time, when parsed, then the minutes are right":
  check fromLegacy("07:05").value == Minutes(425)
  check toLegacy(Minutes(1439)) == "23:59"

# SPEC: GOF-ADAPTER-02
test "GOF-ADAPTER-02 Given malformed strings, when parsed, then each gets its specific error":
  check fromLegacy("").error == aeBadLength
  check fromLegacy("1:30").error == aeBadLength
  check fromLegacy("12-30").error == aeBadSeparator
  check fromLegacy("1a:30").error == aeBadDigit
  check fromLegacy("12:3x").error == aeBadDigit
  check fromLegacy("24:00").error == aeOutOfRange
  check fromLegacy("12:60").error == aeOutOfRange

# SPEC: GOF-ADAPTER-02
test "GOF-ADAPTER-02 Given any string from a mixed alphabet, when parsing succeeds, then formatting gives the same string back":
  let outcome = check(stringOf("0123456789:a-", 0, 7), proc(s: string): bool {.raises: [CatchableError].} =
    let r = fromLegacy(s)
    (not r.isOk) or toLegacy(r.value) == s)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-ADAPTER-03
test "GOF-ADAPTER-03 Given a legacy source of valid times, when adapted, then it equals mapping the parser":
  let outcome = check(seqOf(intIn(0, 1439), 0, 8), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    var strs: seq[string] = @[]
    for x in xs: strs.add(toLegacy(Minutes(x)))
    let src: LegacySource = proc(): seq[string] {.noSideEffect, raises: [].} = strs
    let adapted = adaptAll(src)
    var expected: seq[Minutes] = @[]
    for x in xs: expected.add(Minutes(x))
    adapted.isOk and adapted.value == expected)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-ADAPTER-03
test "GOF-ADAPTER-03 Given a source with two bad entries, when adapted, then the first error is reported":
  let src: LegacySource = proc(): seq[string] {.noSideEffect, raises: [].} =
    @["10:00", "xx:00", "99:99"]
  check adaptAll(src).error == aeBadDigit
