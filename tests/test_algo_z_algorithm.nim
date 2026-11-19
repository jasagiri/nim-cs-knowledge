import std/unittest
import propcheck
import nimcs/algo/z_algorithm

func naiveFindAll(text, pattern: string): seq[int] {.raises: [].} =
  result = @[]
  if pattern.len > text.len:
    return
  for start in 0 .. text.len - pattern.len:
    if text[start ..< start + pattern.len] == pattern:
      result.add start

func commonPrefix(a, b: string): int {.raises: [].} =
  while result < a.len and result < b.len and a[result] == b[result]:
    inc result

# SPEC: STR-ZALGO-01
test "STR-ZALGO-01 Given known strings, when building the Z-array, then it equals the hand-worked one":
  check zArray("aabxaab") == @[7, 1, 0, 0, 3, 1, 0]
  check zArray("aaaa") == @[4, 3, 2, 1]
  check zArray("abcd") == @[4, 0, 0, 0]

# SPEC: STR-ZALGO-01
test "STR-ZALGO-01 Given any string, when building the Z-array, then every entry is the common prefix with that suffix":
  let outcome = check(stringOf("ab", 1, 20), proc(s: string): bool {.raises: [CatchableError].} =
    let z = zArray(s)
    var ok = z.len == s.len
    for i in 1 ..< s.len:
      ok = ok and z[i] == commonPrefix(s, s[i .. ^1])
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: STR-ZALGO-02
test "STR-ZALGO-02 Given a string, when building the Z-array, then entry 0 is its length and the empty string has an empty array":
  check zArray("") == newSeq[int]()
  check zArray("x") == @[1]
  check zArray("hello")[0] == 5

# SPEC: STR-ZALGO-03
test "STR-ZALGO-03 Given any text and pattern, when searching, then the positions equal the naive search":
  let outcome = check(pair(stringOf("ab", 0, 30), stringOf("ab", 1, 4)),
    proc(p: (string, string)): bool {.raises: [CatchableError].} =
      zFindAll(p[0], p[1]) == naiveFindAll(p[0], p[1]))
  checkpoint describe(outcome)
  check outcome.passed
  check zFindAll("aaaa", "aa") == @[0, 1, 2]
  check zFindAll("abab", "ab#") == newSeq[int]()

# SPEC: STR-ZALGO-04
test "STR-ZALGO-04 Given an empty pattern, when searching, then it occurs at every offset including the end":
  check zFindAll("abc", "") == @[0, 1, 2, 3]
  check zFindAll("", "") == @[0]
