import std/[unittest, algorithm, sets, sequtils, strutils]
import propcheck
import nimcs/fp/result
import nimcs/ds/suffix_trie

proc texts(): Gen[string] {.raises: [ValueError].} =
  stringOf("abc", 0, 24)

func trie(s: string): SuffixTrie =
  buildSuffixTrie(s).value

func bruteCount(text, sub: string): int =
  for i in 0 .. text.len - sub.len:
    if text[i ..< i + sub.len] == sub: inc result

func allSubstrings(text: string): HashSet[string] =
  for i in 0 ..< text.len:
    for j in i + 1 .. text.len:
      result.incl text[i ..< j]

func allShorterPresent(n: int; subs: HashSet[string]): bool =
  ## Every string over "abc" of length 1 .. n-1 is a substring.
  var level = @[""]
  for _ in 1 ..< n:
    var next: seq[string]
    for s in level:
      for c in "abc":
        next.add s & c
    level = next
    if level.anyIt(it notin subs): return false
  true

suite "suffix_trie":
  # SPEC: DS-SUFFIXTRIE-01
  test "DS-SUFFIXTRIE-01 Given any text and pattern, when counting, then the trie agrees with a naive scan including overlaps":
    let outcome = check(pair(texts(), stringOf("abc", 0, 5)),
      proc(t: (string, string)): bool {.raises: [CatchableError].} =
        let tr = trie(t[0])
        tr.count(t[1]) == bruteCount(t[0], t[1]) and tr.contains(t[1]) == (t[1] in t[0]))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SUFFIXTRIE-02
  test "DS-SUFFIXTRIE-02 Given any text, when counting distinct substrings, then it equals the size of the set of all substrings":
    let outcome = check(texts(),
      proc(s: string): bool {.raises: [CatchableError].} =
        trie(s).distinctSubstrings == allSubstrings(s).len)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SUFFIXTRIE-03
  test "DS-SUFFIXTRIE-03 Given any text, when asking for the longest repeat, then it is the longest substring seen twice, smallest on ties":
    let outcome = check(texts(),
      proc(s: string): bool {.raises: [CatchableError].} =
        var want = ""
        for sub in allSubstrings(s).toSeq.sorted:
          if bruteCount(s, sub) >= 2 and sub.len > want.len: want = sub
        trie(s).longestRepeated == want)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-SUFFIXTRIE-04
  test "DS-SUFFIXTRIE-04 Given a known text, when querying, then the textbook answers come out":
    let t = trie("banana")
    check t.count("ana") == 2
    check t.count("a") == 3
    check t.count("nana") == 1
    check t.count("x") == 0
    check t.count("") == 7
    check t.distinctSubstrings == 15
    check t.longestRepeated == "ana"
    check "nan" in t and "bnan" notin t

  # SPEC: DS-SUFFIXTRIE-05
  test "DS-SUFFIXTRIE-05 Given the empty text, when querying, then nothing is found and the trie is empty":
    let t = trie("")
    check t.textLen == 0
    check t.distinctSubstrings == 0
    check t.longestRepeated == ""
    check t.count("a") == 0
    check t.count("") == 1
    check "" in t

  # SPEC: DS-SUFFIXTRIE-06
  test "DS-SUFFIXTRIE-06 Given a text over the maximum length, when building, then textTooLong is returned and the maximum itself is accepted":
    check buildSuffixTrie('a'.repeat(maxTextLen + 1)) == err(SuffixTrie, textTooLong)
    check buildSuffixTrie('a'.repeat(maxTextLen)).isOk
    check trie('a'.repeat(maxTextLen)).longestRepeated.len == maxTextLen - 1

  # SPEC: DS-SUFFIXTRIE-07
  test "DS-SUFFIXTRIE-07 Given any text, when asking for the shortest absent string, then it is absent and every shorter string is present":
    let outcome = check(texts(),
      proc(s: string): bool {.raises: [CatchableError].} =
        let tr = trie(s)
        let a = tr.shortestAbsent("abc")
        let subs = allSubstrings(s)
        a notin subs and a.len >= 1 and allShorterPresent(a.len, subs))
    checkpoint describe(outcome)
    check outcome.passed
    check trie("abc").shortestAbsent("abc") == "aa"
    check trie("aabbcc").shortestAbsent("abc") == "ac"
    check trie("x").shortestAbsent("") == ""

  # SPEC: DS-SUFFIXTRIE-08
  test "DS-SUFFIXTRIE-08 Given one text, when building twice, then the answers are identical":
    let a = trie("mississippi")
    let b = trie("mississippi")
    check a.distinctSubstrings == b.distinctSubstrings
    check a.longestRepeated == "issi"
    check a.longestRepeated == b.longestRepeated
    check a.count("ssi") == 2 and a.count("i") == 4
