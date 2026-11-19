## Suffix array by prefix doubling, and the LCP array by Kasai's method.
##
## The suffix array lists the start offsets of all suffixes of a string in sorted order. Prefix
## doubling ranks suffixes by their first 1, 2, 4, ... characters, sorting pairs of ranks until all
## ranks differ: O(n log^2 n) with a comparison sort. The LCP array stores, next to each suffix, the
## length of the prefix it shares with the previous suffix in sorted order; Kasai computes it in O(n)
## by never letting the shared length drop by more than one between neighbouring text positions.
##
## Use it for substring search by binary search, counting distinct substrings and longest
## repeated substring. For a single search `kmp` or `z_algorithm` is simpler; a suffix tree
## answers the same questions with a larger structure.

import std/[algorithm, options]

func suffixArray*(s: string): seq[int] {.raises: [].} =
  ## Offsets of the suffixes of `s` in ascending lexicographic order (STR-SA-01, STR-SA-02).
  let n = s.len
  result = newSeq[int](n)
  if n == 0:
    return
  var rank = newSeq[int](n)
  var next = newSeq[int](n)
  for i in 0 ..< n:
    result[i] = i
    rank[i] = ord(s[i])
  var k = 1
  while true:
    let width = k
    let ranks = rank
    func key(i: int): (int, int) {.raises: [].} =
      (ranks[i], if i + width < n: ranks[i + width] else: -1)
    result.sort(proc(a, b: int): int {.raises: [].} = cmp(key(a), key(b)))
    next[result[0]] = 0
    for i in 1 ..< n:
      next[result[i]] = next[result[i - 1]] + (if key(result[i - 1]) < key(result[i]): 1 else: 0)
    rank = next
    if rank[result[n - 1]] == n - 1:
      break
    k *= 2

func isSuffixArrayOf*(sa: openArray[int]; s: string): bool {.raises: [].} =
  ## True when `sa` is a permutation of 0 ..< s.len whose suffixes are strictly ascending
  ## (STR-SA-01). O(n): after the permutation check, the suffix at `sa[i-1]` is smaller than the
  ## one at `sa[i]` exactly when its first character is smaller, or the first characters are equal
  ## and the rest of the first suffix sits earlier in `sa` (an empty rest sits before everything).
  ## Used by `lcpArray` to reject a bad array, and by tests as the law.
  if sa.len != s.len:
    return false
  var rankOf = newSeq[int](s.len + 1)   # rankOf[s.len] = -1: the empty suffix
  rankOf[s.len] = -1
  var seen = newSeq[bool](s.len)
  for i, at in sa:
    if at < 0 or at >= s.len or seen[at]:
      return false
    seen[at] = true
    rankOf[at] = i
  for i in 1 ..< sa.len:
    let a = sa[i - 1]
    let b = sa[i]
    if s[a] > s[b] or (s[a] == s[b] and rankOf[a + 1] > rankOf[b + 1]):
      return false
  true

func lcpArray*(s: string; sa: openArray[int]): Option[seq[int]] {.raises: [].} =
  ## `result[i]` is the length of the longest common prefix of the suffixes at `sa[i - 1]` and
  ## `sa[i]`; `result[0]` is 0 (STR-SA-03). None when `sa` is not the suffix array of `s`
  ## (STR-SA-04).
  if not isSuffixArrayOf(sa, s):
    return none(seq[int])
  let n = s.len
  var rankOf = newSeq[int](n)
  for i in 0 ..< n:
    rankOf[sa[i]] = i
  var lcp = newSeq[int](n)
  var h = 0
  for i in 0 ..< n:
    if rankOf[i] > 0:
      let j = sa[rankOf[i] - 1]
      while i + h < n and j + h < n and s[i + h] == s[j + h]:
        inc h
      lcp[rankOf[i]] = h
      if h > 0:
        dec h
    else:
      h = 0
  some(lcp)

func countDistinctSubstrings*(s: string): int {.raises: [].} =
  ## Number of different non-empty substrings: all `n(n+1)/2` of them minus the repeated
  ## prefixes the LCP array counts (STR-SA-05).
  let n = s.len
  if n == 0:
    return 0
  let sa = suffixArray(s)
  let lcp = lcpArray(s, sa).get
  result = n * (n + 1) div 2
  for h in lcp:
    result -= h
