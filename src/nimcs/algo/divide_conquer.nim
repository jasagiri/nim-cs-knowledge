## Divide and conquer: split the input, solve the halves, combine. Shown on the maximum-sum
## contiguous subarray, with Kadane's linear scan as the cross-check, and on the master theorem
## that says what a recurrence T(n) = a T(n/b) + Theta(n^d) costs.
##
## `maxSubarrayDc` solves the left half, the right half and the best subarray crossing the middle,
## and keeps the largest: T(n) = 2 T(n/2) + Theta(n) = Theta(n log n). `maxSubarrayKadane`
## does the same in Theta(n) by carrying the best sum ending at the current element. Prefer Kadane
## in practice; the divide-and-conquer form is the one that generalises (e.g. to a segment tree).
## Sums are assumed not to overflow `int`; that is the caller's precondition.

import std/options

type
  Subarray* = object
    ## The slice `xs[first .. last]` (both inclusive) with total `sum`.
    sum*, first*, last*: int

  MasterCase* = enum
    mcRoot      ## a < b^d: the work at the root dominates, T(n) = Theta(n^d)
    mcBalanced  ## a = b^d: every level costs the same, T(n) = Theta(n^d log n)
    mcLeaves    ## a > b^d: the leaves dominate, T(n) = Theta(n^(log_b a))

func maxSubarrayKadane*(xs: openArray[int]): Option[Subarray] {.raises: [].} =
  ## Best non-empty contiguous slice by one scan; none for empty input (TECH-DC-MAXSUB-01,
  ## TECH-DC-MAXSUB-04). On ties it keeps the first slice that reaches the maximum.
  if xs.len == 0:
    return none(Subarray)
  var best = Subarray(sum: xs[0], first: 0, last: 0)
  var cur = best
  for i in 1 ..< xs.len:
    if cur.sum < 0:
      cur = Subarray(sum: xs[i], first: i, last: i)
    else:
      cur = Subarray(sum: cur.sum + xs[i], first: cur.first, last: i)
    if cur.sum > best.sum:
      best = cur
  some(best)

func dcStep(xs: openArray[int]; lo, hi: int): Subarray {.raises: [].} =
  if lo == hi:
    return Subarray(sum: xs[lo], first: lo, last: lo)
  let mid = (lo + hi) div 2
  let left = dcStep(xs, lo, mid)
  let right = dcStep(xs, mid + 1, hi)
  var sum = 0
  var bestLeft = low(int)
  var from0 = mid
  for i in countdown(mid, lo):
    sum += xs[i]
    if sum > bestLeft:
      bestLeft = sum
      from0 = i
  sum = 0
  var bestRight = low(int)
  var to0 = mid + 1
  for i in mid + 1 .. hi:
    sum += xs[i]
    if sum > bestRight:
      bestRight = sum
      to0 = i
  result = left
  let across = Subarray(sum: bestLeft + bestRight, first: from0, last: to0)
  if across.sum > result.sum:
    result = across
  if right.sum > result.sum:
    result = right

func maxSubarrayDc*(xs: openArray[int]): Option[Subarray] {.raises: [].} =
  ## The same maximum by divide and conquer; none for empty input (TECH-DC-MAXSUB-02, TECH-DC-MAXSUB-04).
  ## The sum equals Kadane's; the slice may differ when several slices share the maximum.
  if xs.len == 0: none(Subarray)
  else: some(dcStep(xs, 0, xs.high))

func masterCase*(a, b, d: int): Option[MasterCase] {.raises: [].} =
  ## Which case of the master theorem applies to T(n) = a T(n/b) + Theta(n^d). None unless a >= 1,
  ## b >= 2 and d >= 0 (TECH-DC-MASTER-03). Compares a with b^d without ever forming an overflowing
  ## power (TECH-DC-MASTER-01, TECH-DC-MASTER-02).
  if a < 1 or b < 2 or d < 0:
    return none(MasterCase)
  var p = 1
  for _ in 1 .. d:
    if p > a div b:       # p * b > a: b^d exceeds a however large d is
      return some(mcRoot)
    p *= b
  if a < p: some(mcRoot)
  elif a == p: some(mcBalanced)
  else: some(mcLeaves)
