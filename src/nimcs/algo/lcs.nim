## Longest common subsequence: the longest sequence that can be obtained from both inputs by
## deleting elements (not necessarily contiguous ones).
##
## Use it to compare two sequences when order matters but gaps are allowed (diff tools, DNA
## similarity). The table is a local `var`; the public routines are pure. For contiguous
## matches use `kmp` or `suffix_array` instead.

func lcsLength*[T](a, b: openArray[T]): int {.raises: [].} =
  ## Length of a longest common subsequence (DP-LCS-01, DP-LCS-03).
  var prev = newSeq[int](b.len + 1)
  var cur = newSeq[int](b.len + 1)
  for i in 1 .. a.len:
    for j in 1 .. b.len:
      cur[j] =
        if a[i - 1] == b[j - 1]: prev[j - 1] + 1
        else: max(prev[j], cur[j - 1])
    swap(prev, cur)
  prev[b.len]

func lcs*[T](a, b: openArray[T]): seq[T] {.raises: [].} =
  ## One longest common subsequence. Among the longest ones it is the one the backtrack from the
  ## bottom-right corner finds, preferring to move up on a tie (deterministic, DP-LCS-05).
  let w = b.len + 1
  var table = newSeq[int]((a.len + 1) * w)
  for i in 1 .. a.len:
    for j in 1 .. b.len:
      table[i * w + j] =
        if a[i - 1] == b[j - 1]: table[(i - 1) * w + j - 1] + 1
        else: max(table[(i - 1) * w + j], table[i * w + j - 1])
  var i = a.len
  var j = b.len
  var rev: seq[T] = @[]
  while i > 0 and j > 0:
    if a[i - 1] == b[j - 1]:
      rev.add a[i - 1]
      dec i
      dec j
    elif table[(i - 1) * w + j] >= table[i * w + j - 1]:
      dec i
    else:
      dec j
  result = newSeq[T](rev.len)
  for k in 0 ..< rev.len:
    result[k] = rev[rev.len - 1 - k]

func lcs*(a, b: string): string {.raises: [].} =
  ## The string form of `lcs`.
  var chars: seq[char] = @[]
  for c in lcs(a.toOpenArray(0, a.high), b.toOpenArray(0, b.high)):
    chars.add c
  result = newString(chars.len)
  for k in 0 ..< chars.len:
    result[k] = chars[k]

func isSubsequence*[T](small, big: openArray[T]): bool {.raises: [].} =
  ## True when `small` can be read off `big` left to right with gaps (DP-LCS-02).
  var at = 0
  for x in big:
    if at < small.len and small[at] == x:
      inc at
  at == small.len
