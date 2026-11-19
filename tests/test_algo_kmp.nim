import std/unittest
import propcheck
import nimcs/algo/kmp

func naiveFindAll(text, pattern: string): seq[int] {.raises: [].} =
  result = @[]
  if pattern.len > text.len:
    return
  for start in 0 .. text.len - pattern.len:
    if text[start ..< start + pattern.len] == pattern:
      result.add start

func borderLength(s: string): int {.raises: [].} =
  ## Longest proper border, by checking every candidate length.
  for k in countdown(s.len - 1, 1):
    if s[0 ..< k] == s[s.len - k ..< s.len]:
      return k

func pairs(): Gen[(string, string)] {.raises: [ValueError].} =
  pair(stringOf("ab", 0, 30), stringOf("ab", 0, 4))

# SPEC: STR-KMP-01
test "STR-KMP-01 Given known patterns, when building the failure table, then entries are the longest proper borders":
  check kmpFailure("abab") == @[0, 0, 1, 2]
  check kmpFailure("aaaa") == @[0, 1, 2, 3]
  check kmpFailure("abcd") == @[0, 0, 0, 0]
  check kmpFailure("aabaaab") == @[0, 1, 0, 1, 2, 2, 3]
  check kmpFailure("") == newSeq[int]()

# SPEC: STR-KMP-01
test "STR-KMP-01 Given any pattern, when building the table, then every entry is the longest border of that prefix":
  let outcome = check(stringOf("ab", 0, 14), proc(s: string): bool {.raises: [CatchableError].} =
    let t = kmpFailure(s)
    var ok = t.len == s.len
    for i in 0 ..< s.len:
      ok = ok and t[i] == borderLength(s[0 .. i])
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: STR-KMP-02
test "STR-KMP-02 Given any text and pattern, when searching, then the positions equal the naive search":
  let outcome = check(pairs(), proc(p: (string, string)): bool {.raises: [CatchableError].} =
    kmpFindAll(p[0], p[1]) == naiveFindAll(p[0], p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: STR-KMP-03
test "STR-KMP-03 Given overlapping occurrences, when searching, then all of them are reported in ascending order":
  check kmpFindAll("aaaa", "aa") == @[0, 1, 2]
  check kmpFindAll("abababa", "aba") == @[0, 2, 4]
  check kmpFindAll("abc", "abcd") == newSeq[int]()
  check kmpFindAll("hello world", "o") == @[4, 7]

# SPEC: STR-KMP-04
test "STR-KMP-04 Given an empty pattern, when searching, then it occurs at every offset including the end":
  check kmpFindAll("abc", "") == @[0, 1, 2, 3]
  check kmpFindAll("", "") == @[0]
  check kmpFindAll("", "a") == newSeq[int]()
