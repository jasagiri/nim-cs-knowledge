import std/unittest
import propcheck
import nimcs/patterns/executable_specification

func partGen(): Gen[int] {.raises: [ValueError].} = intIn(0, MaxPart)

func versionGen(): Gen[Version] {.raises: [ValueError].} =
  map(pair(partGen(), pair(partGen(), partGen())),
      proc(x: (int, (int, int))): Version {.raises: [].} = version(x[0], x[1][0], x[1][1]))

# SPEC: PAT-EXECSPEC-01
test "PAT-EXECSPEC-01 Given any version, when its text is parsed, then the same version comes back":
  let outcome = check(versionGen(), proc(v: Version): bool {.raises: [CatchableError].} =
    parseVersion($v) == ok(v, VersionError))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-EXECSPEC-02
test "PAT-EXECSPEC-02 Given any text that parses, when the version is printed, then the text comes back":
  # Parts of zero to seven digits: most texts parse, and leading zeros, empty and long parts occur.
  let digits = stringOf("0123456789", 0, 7)
  let textGen = map(pair(digits, pair(digits, digits)),
      proc(x: (string, (string, string))): string {.raises: [].} = "v" & x[0] & "." & x[1][0] & "." & x[1][1])
  var parsed = 0
  let outcome = check(textGen, proc(s: string): bool {.raises: [CatchableError].} =
    let r = parseVersion(s)
    if r.isOk: inc parsed
    r.isErr or $r.value == s)
  checkpoint describe(outcome)
  check outcome.passed
  check parsed > 0

# SPEC: PAT-EXECSPEC-03
test "PAT-EXECSPEC-03 Given the example table of bad texts, when parsed, then each is the error the table names":
  # The values of the rule live here, once: the specification states only the obligation.
  let table: seq[Example[string, Result[Version, VersionError]]] = @[
    (name: "empty", input: "", expected: err(Version, veShape)),
    (name: "no v", input: "1.2.3", expected: err(Version, veShape)),
    (name: "two parts", input: "v1.2", expected: err(Version, veShape)),
    (name: "four parts", input: "v1.2.3.4", expected: err(Version, veShape)),
    (name: "empty part", input: "v1..3", expected: err(Version, veShape)),
    (name: "sign", input: "v1.-2.3", expected: err(Version, veShape)),
    (name: "space", input: "v1.2.3 ", expected: err(Version, veShape)),
    (name: "leading zero", input: "v1.02.3", expected: err(Version, veLeadingZero)),
    (name: "seven digits", input: "v1.2.1000000", expected: err(Version, veTooLarge)),
    (name: "first bad part decides", input: "v1000000.x.3", expected: err(Version, veTooLarge)),
    (name: "zero alone", input: "v0.0.0", expected: ok(version(0, 0, 0), VersionError)),
    (name: "six digits", input: "v999999.0.1", expected: ok(version(999_999, 0, 1), VersionError))]
  check failures(table, parseVersion).len == 0

# SPEC: PAT-EXECSPEC-04
test "PAT-EXECSPEC-04 Given any two versions, when compared, then the order is that of their part triples":
  let outcome = check(pair(versionGen(), versionGen()), proc(x: (Version, Version)): bool {.raises: [CatchableError].} =
    let (a, b) = x
    let ta = (a.major, a.minor, a.patch)
    let tb = (b.major, b.minor, b.patch)
    (a < b) == (ta < tb) and (a <= b) == (ta <= tb))
  checkpoint describe(outcome)
  check outcome.passed
  check version(1, 9, 9) < version(1, 10, 0)   # numbers, not text: "1.10" is after "1.9"

# SPEC: PAT-EXECSPEC-05
test "PAT-EXECSPEC-05 Given a table and a function, when the table is run, then exactly the disagreeing rows are named in order":
  let outcome = check(seqOf(pair(intIn(-5, 5), intIn(-5, 5)), 0, 8),
      proc(rows: seq[(int, int)]): bool {.raises: [CatchableError].} =
    var table: seq[Example[int, int]]
    var expected: seq[string]
    for i, (input, out0) in rows:
      table.add (name: "row" & $i, input: input, expected: out0)
      if abs(input) != out0: expected.add "row" & $i
    let absolute = proc(x: int): int {.noSideEffect, raises: [].} = abs(x)
    failures(table, absolute) == expected)
  checkpoint describe(outcome)
  check outcome.passed
