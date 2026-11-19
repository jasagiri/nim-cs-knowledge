import std/[unittest, options, algorithm, sets, strutils]
import propcheck
import nimcs/algo/suffix_array

func bruteSa(s: string): seq[int] {.raises: [].} =
  ## Sort the suffix strings themselves.
  var pairs: seq[(string, int)] = @[]
  for i in 0 ..< s.len:
    pairs.add (s[i .. ^1], i)
  pairs.sort(proc(x, y: (string, int)): int {.raises: [].} = cmp(x[0], y[0]))
  result = @[]
  for p in pairs:
    result.add p[1]

func commonPrefix(a, b: string): int {.raises: [].} =
  while result < a.len and result < b.len and a[result] == b[result]:
    inc result

# SPEC: STR-SA-01
test "STR-SA-01 Given any string, when building the suffix array, then it is a permutation listing suffixes in strictly sorted order":
  let outcome = check(stringOf("abc", 0, 20), proc(s: string): bool {.raises: [CatchableError].} =
    let sa = suffixArray(s)
    isSuffixArrayOf(sa, s) and sa == bruteSa(s))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: STR-SA-02
test "STR-SA-02 Given known strings, when building the suffix array, then it equals the hand-worked one":
  check suffixArray("banana") == @[5, 3, 1, 0, 4, 2]
  check suffixArray("aaaa") == @[3, 2, 1, 0]
  check suffixArray("abc") == @[0, 1, 2]
  check suffixArray("x") == @[0]
  check suffixArray("") == newSeq[int]()

# SPEC: STR-SA-03
test "STR-SA-03 Given any string, when building the LCP array, then each entry is the shared prefix with the previous suffix":
  let outcome = check(stringOf("ab", 0, 20), proc(s: string): bool {.raises: [CatchableError].} =
    let sa = suffixArray(s)
    let lcp = lcpArray(s, sa)
    var ok = lcp.isSome and lcp.get.len == s.len
    if ok:
      for i in 0 ..< s.len:
        let expected = if i == 0: 0 else: commonPrefix(s[sa[i - 1] .. ^1], s[sa[i] .. ^1])
        ok = ok and lcp.get[i] == expected
    ok)
  checkpoint describe(outcome)
  check outcome.passed
  check lcpArray("banana", suffixArray("banana")).get == @[0, 1, 3, 0, 0, 2]

# SPEC: STR-SA-04
test "STR-SA-04 Given an array that is not the suffix array of the string, when building the LCP array, then the result is none":
  check lcpArray("banana", [0, 1, 2, 3, 4, 5]).isNone
  check lcpArray("banana", [5, 3, 1, 0, 4]).isNone
  check lcpArray("banana", [5, 3, 1, 0, 4, 4]).isNone
  check lcpArray("banana", [5, 3, 1, 0, 4, 9]).isNone
  check isSuffixArrayOf([1, 0], "ab") == false

# SPEC: STR-SA-05
test "STR-SA-05 Given any string, when counting distinct substrings, then the count equals the size of the set of all substrings":
  let outcome = check(stringOf("abc", 0, 14), proc(s: string): bool {.raises: [CatchableError].} =
    var all = initHashSet[string]()
    for i in 0 ..< s.len:
      for j in i ..< s.len:
        all.incl s[i .. j]
    countDistinctSubstrings(s) == all.len)
  checkpoint describe(outcome)
  check outcome.passed
  check countDistinctSubstrings("banana") == 15

func naiveValid(sa: seq[int]; s: string): bool {.raises: [].} =
  if sa.len != s.len: return false
  var seen = newSeq[bool](s.len)
  for at in sa:
    if at < 0 or at >= s.len or seen[at]: return false
    seen[at] = true
  for i in 1 ..< sa.len:
    if not (s[sa[i - 1] .. ^1] < s[sa[i] .. ^1]): return false
  true

# SPEC: STR-SA-06
test "STR-SA-06 Given any string and any candidate array, when validating, then the linear check agrees with comparing the suffix strings":
  let outcome = check(pair(stringOf("ab", 0, 7), seqOf(intIn(-1, 8), 0, 8)),
    proc(p: (string, seq[int])): bool {.raises: [CatchableError].} =
      let (s, cand) = p
      # Mostly arbitrary arrays (many invalid), plus the true array and a swapped copy of it.
      var swapped = suffixArray(s)
      if swapped.len >= 2: swap(swapped[0], swapped[^1])
      isSuffixArrayOf(cand, s) == naiveValid(cand, s) and
        isSuffixArrayOf(suffixArray(s), s) and
        isSuffixArrayOf(swapped, s) == naiveValid(swapped, s))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: STR-SA-06
test "STR-SA-06 Given a long repetitive string, when counting distinct substrings, then the validation does not make it quadratic":
  let s = 'a'.repeat(40000)
  check countDistinctSubstrings(s) == 40000
