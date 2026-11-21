## Two pointers and sliding window: scan a sequence once with two moving indices.
##
## Use them when a property can only improve (or only worsen) as an index moves, so each index
## needs to move one way only and the total work is O(n) instead of O(n^2). Here: finding a pair
## of a sorted sequence that adds to a target (pointers from both ends), the longest window of
## non-negative numbers whose sum stays within a bound (window grows right, shrinks left), and the
## sums of all windows of one fixed size. Sums are `int`; the caller keeps them from overflowing.

import nimcs/fp/result

type
  PairError* = enum
    peNotSorted   ## the input is not in ascending order, so the method would give wrong answers
    peNoPair      ## no two elements add up to the target

  Window* = object
    ## `len` consecutive elements from index `start`; `len == 0` is the empty window.
    start*, len*: int

  WindowError* = enum
    weNegativeElement   ## the window method needs non-negative numbers: a negative one breaks "shrinking never raises the sum"
    weNegativeBound     ## no window, not even the empty one, has a sum below zero
    weBadSize           ## a fixed window size below one

func `==`*(a, b: Window): bool {.raises: [].} =
  a.start == b.start and a.len == b.len

func pairWithSum*(sortedXs: openArray[int]; target: int): Result[(int, int), PairError] {.raises: [].} =
  ## Indices (i, j), i < j, with `sortedXs[i] + sortedXs[j] == target`. When several pairs exist
  ## it is the one with the smallest i and, for that i, the largest j (TECH-TWOPTR-01).
  ## Fails with `peNotSorted` on an input that is not ascending (TECH-TWOPTR-03) and with
  ## `peNoPair` when there is none (TECH-TWOPTR-02).
  for k in 1 ..< sortedXs.len:
    if sortedXs[k - 1] > sortedXs[k]:
      return err((int, int), peNotSorted)
  var lo = 0
  var hi = sortedXs.len - 1
  while lo < hi:
    let sum = sortedXs[lo] + sortedXs[hi]
    if sum == target:
      return ok((lo, hi), PairError)
    if sum < target:
      inc lo               # no pair with this lo can be larger: even the biggest partner is too small
    else:
      dec hi               # no pair with this hi can be smaller: even the smallest partner is too big
  err((int, int), peNoPair)

func longestWindowAtMost*(xs: openArray[int]; bound: int): Result[Window, WindowError] {.raises: [].} =
  ## The longest run of consecutive elements whose sum is at most `bound`; the earliest one when
  ## several have the longest length (TECH-WINDOW-01). `xs` must be non-negative
  ## (TECH-WINDOW-03) and `bound` at least zero (TECH-WINDOW-04), so the empty window always
  ## qualifies and a result always exists.
  if bound < 0:
    return err(Window, weNegativeBound)
  for x in xs:
    if x < 0:
      return err(Window, weNegativeElement)
  var best = Window(start: 0, len: 0)
  var left = 0
  var sum = 0
  for right in 0 ..< xs.len:
    sum += xs[right]
    while sum > bound:
      sum -= xs[left]
      inc left
    if right - left + 1 > best.len:
      best = Window(start: left, len: right - left + 1)
  ok(best, WindowError)

func windowSums*(xs: openArray[int]; size: int): Result[seq[int], WindowError] {.raises: [].} =
  ## The sum of every run of `size` consecutive elements, left to right: `xs.len - size + 1` sums,
  ## none when `size` exceeds the length. Each step adds the entering element and drops the
  ## leaving one instead of re-adding the window (TECH-WINDOW-02). Fails when `size` < 1 (TECH-WINDOW-05).
  if size < 1:
    return err(seq[int], weBadSize)
  var sums: seq[int]
  var current = 0
  for i in 0 ..< xs.len:
    current += xs[i]
    if i >= size:
      current -= xs[i - size]
    if i >= size - 1:
      sums.add current
  ok(sums, WindowError)
