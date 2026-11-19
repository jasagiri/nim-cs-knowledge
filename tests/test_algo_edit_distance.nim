import std/[unittest, options]
import propcheck
import nimcs/algo/edit_distance

func pairs(): Gen[(string, string)] {.raises: [ValueError].} =
  pair(stringOf("abc", 0, 9), stringOf("abc", 0, 9))

# SPEC: DP-EDIT-01
test "DP-EDIT-01 Given known pairs, when computing the distance, then it matches the hand-worked answer":
  check editDistance("kitten", "sitting") == 3
  check editDistance("", "abc") == 3
  check editDistance("abc", "") == 3
  check editDistance("flaw", "lawn") == 2
  check editDistance("same", "same") == 0

# SPEC: DP-EDIT-02
test "DP-EDIT-02 Given any string, when measured against itself, then the distance is 0 (and 0 only for equal strings)":
  let outcome = check(pairs(), proc(p: (string, string)): bool {.raises: [CatchableError].} =
    editDistance(p[0], p[0]) == 0 and ((editDistance(p[0], p[1]) == 0) == (p[0] == p[1])))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: DP-EDIT-03
test "DP-EDIT-03 Given any two strings, when swapping them, then the distance is the same":
  let outcome = check(pairs(), proc(p: (string, string)): bool {.raises: [CatchableError].} =
    editDistance(p[0], p[1]) == editDistance(p[1], p[0]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: DP-EDIT-04
test "DP-EDIT-04 Given three strings, when comparing distances, then the triangle inequality holds and d(a,b) <= max(len a, len b)":
  let outcome = check(pair(pairs(), stringOf("abc", 0, 9)),
    proc(p: ((string, string), string)): bool {.raises: [CatchableError].} =
      let a = p[0][0]
      let b = p[0][1]
      let c = p[1]
      editDistance(a, c) <= editDistance(a, b) + editDistance(b, c) and
        editDistance(a, b) <= max(a.len, b.len) and
        editDistance(a, b) >= abs(a.len - b.len))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: DP-EDIT-05
test "DP-EDIT-05 Given any two strings, when scripting the edit, then the script costs the distance and is repeatable":
  let outcome = check(pairs(), proc(p: (string, string)): bool {.raises: [CatchableError].} =
    let s = editScript(p[0], p[1])
    cost(s) == editDistance(p[0], p[1]) and s == editScript(p[0], p[1]))
  checkpoint describe(outcome)
  check outcome.passed
  check cost(editScript("kitten", "sitting")) == 3

# SPEC: DP-EDIT-06
test "DP-EDIT-06 Given the script from a to b, when applied to a, then the result is b; a script that does not fit gives none":
  let outcome = check(pairs(), proc(p: (string, string)): bool {.raises: [CatchableError].} =
    applyScript(p[0], editScript(p[0], p[1])) == some(p[1]))
  checkpoint describe(outcome)
  check outcome.passed
  check applyScript("abc", [keep('a')]).isNone
  check applyScript("abc", [keep('x'), keep('b'), keep('c')]).isNone
  check applyScript("a", [keep('a'), delete('b')]).isNone
  check applyScript("", [insert('z')]) == some("z")
