## Longest strictly increasing subsequence in O(n log n), with reconstruction.
##
## Keep, for every length L, the smallest tail value of an increasing subsequence of length L
## found so far; the tails are sorted, so each new element is placed by binary search. Parent
## links then rebuild one subsequence. Use it for patience-sorting style problems, "fewest moves
## to sort" questions and as the fast alternative to a quadratic table. For the non-strict
## version, compare with `<=` by searching for the first tail greater than the element.

func lisIndices*[T](xs: openArray[T]): seq[int] {.raises: [].} =
  ## Indices (ascending) of one longest strictly increasing subsequence. Of the longest ones it
  ## returns the one that ends in the smallest final value (the last tail kept); the choice is
  ## fixed by the input, so repeated calls agree (DP-LIS-04).
  var tailIdx: seq[int] = @[]       # tailIdx[L-1] = index of the best tail of length L
  var parent = newSeq[int](xs.len)  # previous index in the subsequence, or -1
  for i in 0 ..< xs.len:
    var lo = 0
    var hi = tailIdx.len
    while lo < hi:
      let mid = (lo + hi) div 2
      if xs[tailIdx[mid]] < xs[i]: lo = mid + 1
      else: hi = mid
    parent[i] = if lo > 0: tailIdx[lo - 1] else: -1
    if lo == tailIdx.len: tailIdx.add i
    else: tailIdx[lo] = i
  var rev: seq[int] = @[]
  var at = if tailIdx.len > 0: tailIdx[tailIdx.len - 1] else: -1
  while at >= 0:
    rev.add at
    at = parent[at]
  result = newSeq[int](rev.len)
  for k in 0 ..< rev.len:
    result[k] = rev[rev.len - 1 - k]

func lis*[T](xs: openArray[T]): seq[T] {.raises: [].} =
  ## The values of one longest strictly increasing subsequence (DP-LIS-01 .. DP-LIS-03).
  let idx = lisIndices(xs)
  result = newSeq[T](idx.len)
  for k in 0 ..< idx.len:
    result[k] = xs[idx[k]]

func lisLength*[T](xs: openArray[T]): int {.raises: [].} =
  lisIndices(xs).len
