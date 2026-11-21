import std/[algorithm, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/kmp
import nimcs/algo/aho_corasick

func naiveFindAll(text: string; patterns: seq[string]): seq[Match] {.raises: [].} =
  ## Every (start, pattern) pair by comparing at each offset.
  for index, p in patterns:
    if p.len > text.len:
      continue
    for start in 0 .. text.len - p.len:
      if text[start ..< start + p.len] == p:
        result.add Match(start: start, pattern: index)
  result.sort

func automaton(patterns: seq[string]): AhoCorasick {.raises: [].} =
  ## The generated patterns are never empty, so building cannot fail.
  buildAho(patterns).value

proc inputs(): Gen[(string, seq[string])] {.raises: [ValueError].} =
  pair(stringOf("ab", 0, 30), seqOf(stringOf("ab", 1, 4), 0, 6))

# SPEC: STR-AHOCORASICK-01
test "STR-AHOCORASICK-01 Given the classic he/she/his/hers set, when searching, then the hand-worked matches come back":
  let a = automaton(@["he", "she", "his", "hers"])
  check a.findAll("ushers") == @[Match(start: 1, pattern: 1), Match(start: 2, pattern: 0),
                                 Match(start: 2, pattern: 3)]
  check a.findAll("ahishers") == @[Match(start: 1, pattern: 2), Match(start: 3, pattern: 1),
                                   Match(start: 4, pattern: 0), Match(start: 4, pattern: 3)]
  check a.findAll("xyz").len == 0
  check a.findAll("").len == 0

# SPEC: STR-AHOCORASICK-01
test "STR-AHOCORASICK-01 Given any text and pattern set, when searching, then the matches equal the naive search":
  let outcome = check(inputs(), proc(p: (string, seq[string])): bool {.raises: [CatchableError].} =
    automaton(p[1]).findAll(p[0]) == naiveFindAll(p[0], p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: STR-AHOCORASICK-02
test "STR-AHOCORASICK-02 Given patterns that overlap or contain one another, when searching, then every occurrence is reported once":
  let a = automaton(@["a", "aa", "aaa"])
  check a.findAll("aaaa").len == 4 + 3 + 2
  let b = automaton(@["abab", "ab", "b"])
  check b.findAll("ababab") == naiveFindAll("ababab", @["abab", "ab", "b"])

# SPEC: STR-AHOCORASICK-02
test "STR-AHOCORASICK-02 Given any search, when it finishes, then matches ascend by start then pattern and fit inside the text":
  let outcome = check(inputs(), proc(p: (string, seq[string])): bool {.raises: [CatchableError].} =
    let found = automaton(p[1]).findAll(p[0])
    var ok = found.isSorted
    for m in found:
      let len = p[1][m.pattern].len
      ok = ok and m.start >= 0 and m.start + len <= p[0].len
      ok = ok and p[0][m.start ..< m.start + len] == p[1][m.pattern]
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: STR-AHOCORASICK-03
test "STR-AHOCORASICK-03 Given a single pattern, when searching, then the starts equal the KMP search":
  let outcome = check(pair(stringOf("ab", 0, 30), stringOf("ab", 1, 4)),
                      proc(p: (string, string)): bool {.raises: [CatchableError].} =
    var starts: seq[int]
    for m in automaton(@[p[1]]).findAll(p[0]):
      starts.add m.start
    starts == kmpFindAll(p[0], p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: STR-AHOCORASICK-04
test "STR-AHOCORASICK-04 Given any text and pattern set, when counting, then each count equals the matches of that pattern":
  let outcome = check(inputs(), proc(p: (string, seq[string])): bool {.raises: [CatchableError].} =
    let a = automaton(p[1])
    var expected = newSeq[int](p[1].len)
    for m in a.findAll(p[0]):
      inc expected[m.pattern]
    a.countAll(p[0]) == expected and a.patternCount == p[1].len)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: STR-AHOCORASICK-05
test "STR-AHOCORASICK-05 Given an empty pattern in the set, when building, then the build fails":
  check buildAho(@["ab", ""]).error == aeEmptyPattern
  check buildAho(@[""]).isErr
  check buildAho(newSeq[string]()).isOk

# SPEC: STR-AHOCORASICK-06
test "STR-AHOCORASICK-06 Given duplicate patterns, when searching, then each index is reported at the same offsets":
  let a = automaton(@["ab", "ab"])
  check a.findAll("abab") == @[Match(start: 0, pattern: 0), Match(start: 0, pattern: 1),
                               Match(start: 2, pattern: 0), Match(start: 2, pattern: 1)]

# SPEC: STR-AHOCORASICK-07
test "STR-AHOCORASICK-07 Given one automaton, when searching twice or after rebuilding, then the answers repeat":
  let outcome = check(inputs(), proc(p: (string, seq[string])): bool {.raises: [CatchableError].} =
    let a = automaton(p[1])
    let first = a.findAll(p[0])
    first == a.findAll(p[0]) and first == automaton(p[1]).findAll(p[0]))
  checkpoint describe(outcome)
  check outcome.passed
