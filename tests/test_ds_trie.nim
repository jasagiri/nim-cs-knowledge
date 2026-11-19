import std/[unittest, algorithm, sets, sequtils, strutils]
import propcheck
import nimcs/ds/trie

proc words(): Gen[seq[string]] {.raises: [ValueError].} =
  seqOf(stringOf("abc", 0, 5), 0, 40)

suite "trie":
  # SPEC: DS-TRIE-01
  test "DS-TRIE-01 Given any words, when inserted, then contains is true exactly for the inserted words":
    let outcome = check(pair(words(), stringOf("abc", 0, 5)),
      proc(a: (seq[string], string)): bool {.raises: [CatchableError].} =
        let t = fromSeq(a[0])
        for w in a[0]:
          if not t.contains(w): return false
        t.contains(a[1]) == (a[1] in a[0]))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-TRIE-02
  test "DS-TRIE-02 Given any words and prefix, when listing keysWithPrefix, then the result is the sorted distinct words with that prefix":
    let outcome = check(pair(words(), stringOf("abc", 0, 3)),
      proc(a: (seq[string], string)): bool {.raises: [CatchableError].} =
        let t = fromSeq(a[0])
        let expected = a[0].toHashSet.toSeq.filterIt(it.startsWith(a[1])).sorted
        t.keysWithPrefix(a[1]) == expected)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-TRIE-03
  test "DS-TRIE-03 Given a word already present, when inserted again, then the trie is unchanged in size and content":
    let outcome = check(words(),
      proc(ws: seq[string]): bool {.raises: [CatchableError].} =
        let t = fromSeq(ws)
        for w in ws:
          if t.insert(w).toSeq != t.toSeq or t.insert(w).len != t.len: return false
        t.len == ws.toHashSet.len)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-TRIE-04
  test "DS-TRIE-04 Given a trie, when inserting a word, then the old trie is unchanged":
    let t = fromSeq(["car", "cat"])
    let u = t.insert("cow")
    check t.toSeq == @["car", "cat"]
    check u.toSeq == @["car", "cat", "cow"]
    check not t.contains("cow")

  # SPEC: DS-TRIE-05
  test "DS-TRIE-05 Given words where one is a prefix of another, when queried, then the prefix is a word only if inserted":
    let t = fromSeq(["car", "carpet"])
    check t.contains("car")
    check t.contains("carpet")
    check not t.contains("carp")
    check t.hasPrefix("carp")
    check not t.hasPrefix("cat")
    check t.keysWithPrefix("car") == @["car", "carpet"]

  # SPEC: DS-TRIE-06
  test "DS-TRIE-06 Given the empty trie or the empty word, when queried, then results are empty or exact":
    let e = emptyTrie()
    check e.isEmpty
    check e.keysWithPrefix("").len == 0
    check not e.contains("")
    let t = e.insert("")
    check t.contains("")
    check t.toSeq == @[""]
    check t.len == 1
