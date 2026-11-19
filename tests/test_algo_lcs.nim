import std/[unittest]
import propcheck
import nimcs/algo/lcs

func subsequences(s: string): seq[string] {.raises: [].} =
  ## Every subsequence of `s` (2^len of them); the reference the DP is judged against.
  result = @[]
  for mask in 0 ..< (1 shl s.len):
    var t = ""
    for i in 0 ..< s.len:
      if ((mask shr i) and 1) == 1:
        t.add s[i]
    result.add t

func bruteLcsLength(a, b: string): int {.raises: [].} =
  for t in subsequences(a):
    if t.len > result and isSubsequence(t, b):
      result = t.len

# SPEC: DP-LCS-01
test "DP-LCS-01 Given known pairs, when computing the length, then it matches the hand-worked answer":
  check lcsLength("", "abc") == 0
  check lcsLength("abc", "") == 0
  check lcsLength("abcbdab", "bdcaba") == 4
  check lcsLength("AGGTAB", "GXTXAYB") == 4
  check lcsLength("abc", "xyz") == 0
  check lcsLength(@[1, 2, 3, 4], @[2, 4, 6]) == 2

# SPEC: DP-LCS-02
test "DP-LCS-02 Given any two strings, when taking the lcs, then the result is a subsequence of both":
  let outcome = check(pair(stringOf("abc", 0, 12), stringOf("abc", 0, 12)),
    proc(p: (string, string)): bool {.raises: [CatchableError].} =
      let c = lcs(p[0], p[1])
      isSubsequence(c, p[0]) and isSubsequence(c, p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: DP-LCS-03
test "DP-LCS-03 Given any two strings, when comparing length and lcs, then the length agrees and is optimal":
  let outcome = check(pair(stringOf("ab", 0, 8), stringOf("ab", 0, 8)),
    proc(p: (string, string)): bool {.raises: [CatchableError].} =
      let n = lcsLength(p[0], p[1])
      lcs(p[0], p[1]).len == n and n == bruteLcsLength(p[0], p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: DP-LCS-04
test "DP-LCS-04 Given any two strings, when swapping them, then the length is the same and bounded by the shorter":
  let outcome = check(pair(stringOf("abc", 0, 12), stringOf("abc", 0, 12)),
    proc(p: (string, string)): bool {.raises: [CatchableError].} =
      let n = lcsLength(p[0], p[1])
      n == lcsLength(p[1], p[0]) and n <= min(p[0].len, p[1].len))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: DP-LCS-05
test "DP-LCS-05 Given a string, when taking lcs with itself, then the result is the string; and the call is repeatable":
  let outcome = check(pair(stringOf("abc", 0, 12), stringOf("abc", 0, 12)),
    proc(p: (string, string)): bool {.raises: [CatchableError].} =
      lcs(p[0], p[0]) == p[0] and lcs(p[0], p[1]) == lcs(p[0], p[1]))
  checkpoint describe(outcome)
  check outcome.passed
  check lcs("abcbdab", "bdcaba").len == 4
