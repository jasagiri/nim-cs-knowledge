## Meet in the middle: subset sums in about 2^(n/2) work instead of 2^n.
##
## Split the items into two halves, list every subset sum of each half (at most 2^(n/2) sums), sort
## both lists, and combine them: a subset of the whole is one subset of each half, so a target is
## reached exactly when some left sum plus some right sum equals it, which a binary search on the
## sorted right list finds. Use it when n is too big for 2^n (n around 30 to 40) but too small for
## a pseudo-polynomial table because the values are large; when the values are small, `knapsack`
## style dynamic programming is cheaper.
##
## Subsets are counted by index: two equal items are distinct choices, and the empty subset has
## sum 0. Items may be negative. To keep every sum inside `int`, at most `MaxItems` items of
## absolute value at most `MaxItemValue` are accepted and the target must have absolute value at
## most `MaxTarget`.

import std/[algorithm, options]
import nimcs/fp/result

const
  MaxItems*: int = 40              ## at most this many items (two halves of at most 20)
  MaxItemValue*: int = 1_000_000_000_000   ## |item| <= this, so 40 items sum to at most 4e13
  MaxTarget*: int = 1_000_000_000_000_000  ## |target| <= this, so differences stay far below 2^63

type MitmError* = enum
  meTooManyItems   ## more than MaxItems items
  meItemTooLarge   ## an item has absolute value above MaxItemValue
  meTargetTooLarge ## the target has absolute value above MaxTarget

func halfSums(items: openArray[int]): seq[int] {.raises: [].} =
  ## All 2^len subset sums of `items`, ascending (duplicates kept).
  result = @[0]
  for x in items:
    var more = newSeq[int](result.len)
    for i, s in result:
      more[i] = s + x
    result = result & more
  result.sort

func violation(items: openArray[int]; target: int): Option[MitmError] {.raises: [].} =
  ## The first limit the input breaks, if any (MITM-LIMIT-01).
  if items.len > MaxItems:
    return some(meTooManyItems)
  for x in items:
    if abs(x) > MaxItemValue:
      return some(meItemTooLarge)
  if abs(target) > MaxTarget:
    return some(meTargetTooLarge)
  none(MitmError)

func halves(items: openArray[int]): (seq[int], seq[int]) {.raises: [].} =
  let mid = items.len div 2
  (halfSums(items[0 ..< mid]), halfSums(items[mid ..< items.len]))

func countSubsetSum*(items: openArray[int]; target: int): Result[int, MitmError] {.raises: [].} =
  ## The number of index-distinct subsets of `items` (the empty one included) whose sum is
  ## `target` (MITM-COUNT-01, MITM-COUNT-02).
  let broken = violation(items, target)
  if broken.isSome:
    return err(int, broken.get)
  let (left, right) = halves(items)
  var total = 0
  for l in left:
    let want = target - l
    total += right.upperBound(want) - right.lowerBound(want)
  ok(total, MitmError)

func subsetSumExists*(items: openArray[int]; target: int): Result[bool, MitmError] {.raises: [].} =
  ## Does some subset of `items` (possibly empty) sum to `target`? (MITM-EXISTS-01)
  let count = countSubsetSum(items, target)
  if count.isErr:
    return err(bool, count.error)
  ok(count.value > 0, MitmError)

func closestSubsetSum*(items: openArray[int]; target: int): Result[int, MitmError] {.raises: [].} =
  ## The subset sum nearest to `target`; on a tie the smaller sum (MITM-CLOSEST-01,
  ## MITM-CLOSEST-02).
  let broken = violation(items, target)
  if broken.isSome:
    return err(int, broken.get)
  let (left, right) = halves(items)
  var best = left[0] + right[0]
  for l in left:
    let want = target - l
    let at = right.lowerBound(want)     # first right sum >= want
    for i in [at - 1, at]:
      if i >= 0 and i < right.len:
        let s = l + right[i]
        let gap = abs(s - target)
        let bestGap = abs(best - target)
        if gap < bestGap or (gap == bestGap and s < best):
          best = s
  ok(best, MitmError)
