## Asymptotic and amortized analysis, made measurable by counting operations instead of time.
##
## Use it to check an analysis claim against a count: how many comparisons does a search make, how
## many element copies does a growing array pay, how many bit flips does a counter pay. A count
## is exact and repeatable, a stopwatch is neither. Big-O statements are about all large inputs,
## so the witness checks here (`isBigOOn`, `isBigOmegaOn`) test a stated constant over a finite
## range: they refute a wrong claim and support a right one, but do not prove it.

import std/options

type
  Growth* = enum
    gDoubling   ## a full array gets twice the capacity (capacity 0 becomes 1)
    gByOne      ## a full array gets one more slot

  AppendStep* = object
    ## One append to a growing array, after it happened.
    cost*: int        ## 1 for the write plus the elements copied by a resize
    size*: int        ## elements held
    capacity*: int    ## slots allocated

  Measure = proc(n: int): int {.noSideEffect, raises: [].}

func ceilLog2*(n: int): Option[int] {.raises: [].} =
  ## The smallest k with 2^k >= n, for n >= 1; none otherwise.
  if n < 1:
    return none(int)
  var k = 0
  var reach = 1
  while reach < n:
    reach *= 2
    inc k
  some(k)

func linearSearchSteps*(xs: openArray[int]; x: int): int {.raises: [].} =
  ## Elements looked at while scanning from the left for `x`: its position plus one when
  ## present, the length otherwise. Worst case n, so the cost is Theta(n) in the worst case.
  for i, v in xs:
    if v == x:
      return i + 1
  xs.len

func binarySearchSteps*(sortedXs: openArray[int]; x: int): int {.raises: [].} =
  ## Probes made by binary search on an ascending sequence (one probe = one three-way comparison
  ## with the middle element). At most floor(log2 n) + 1 for n >= 1 (ANALYSIS-ASYMP-02).
  var lo = 0
  var hi = sortedXs.len - 1
  while lo <= hi:
    inc result
    let mid = lo + (hi - lo) div 2
    if sortedXs[mid] == x:
      return
    if sortedXs[mid] < x: lo = mid + 1 else: hi = mid - 1

func naiveDuplicateComparisons*(xs: openArray[int]): tuple[found: bool, comparisons: int] {.raises: [].} =
  ## Compares every pair (i < j) until two are equal. With no duplicate it makes exactly
  ## n * (n - 1) / 2 comparisons: a nested loop is Theta(n^2) (ANALYSIS-ASYMP-01).
  for i in 0 ..< xs.len:
    for j in i + 1 ..< xs.len:
      inc result.comparisons
      if xs[i] == xs[j]:
        result.found = true
        return

func isBigOOn*(f, g: Measure; c, n0, upTo: int): bool {.raises: [].} =
  ## Does f(n) <= c * g(n) hold for every n in n0 .. upTo? A finite check of the claim
  ## "f is O(g) with constant c from n0 on" (ANALYSIS-ASYMP-03): `false` refutes the claim for
  ## these constants, `true` supports it up to `upTo` only.
  for n in n0 .. upTo:
    if f(n) > c * g(n):
      return false
  true

func isBigOmegaOn*(f, g: Measure; c, n0, upTo: int): bool {.raises: [].} =
  ## Does f(n) >= c * g(n) hold for every n in n0 .. upTo? (the lower-bound twin of `isBigOOn`.)
  for n in n0 .. upTo:
    if f(n) < c * g(n):
      return false
  true

func appendSteps*(n: int; growth: Growth): seq[AppendStep] {.raises: [].} =
  ## The cost of each of `n` appends to an empty growing array (none for n <= 0). Without a
  ## resize an append costs 1; a resize also copies every element already held, so it costs 1 + size.
  var size = 0
  var capacity = 0
  for _ in 1 .. n:
    var cost = 1
    if size == capacity:
      cost += size
      capacity = if growth == gDoubling: max(1, 2 * capacity) else: capacity + 1
    inc size
    result.add AppendStep(cost: cost, size: size, capacity: capacity)

func totalCost*(steps: openArray[AppendStep]): int {.raises: [].} =
  ## The aggregate method: add the real costs. Doubling: at most 3n for n appends
  ## (ANALYSIS-AMORT-01); growing by one: n + n(n - 1) / 2 (ANALYSIS-AMORT-02).
  for s in steps:
    result += s.cost

func potential*(size, capacity: int): int {.raises: [].} =
  ## Phi = 2 * size - capacity: the unspent "credit" of a doubling array. It is zero when empty,
  ## never negative while the array is more than half full, and is spent exactly when a resize copies.
  2 * size - capacity

func doublingAmortizedCosts*(n: int): seq[int] {.raises: [].} =
  ## The potential method for doubling: amortized cost of append i is its real cost plus
  ## Phi after minus Phi before. Each is at most 3 (ANALYSIS-AMORT-03), whatever the resizes.
  var before = 0
  for s in appendSteps(n, gDoubling):
    let after = potential(s.size, s.capacity)
    result.add s.cost + after - before
    before = after

func incrementBits*(bits: seq[bool]): tuple[bits: seq[bool], flips: int] {.raises: [].} =
  ## Adds one to a binary counter (least significant bit first; the counter grows by a bit on
  ## overflow) and counts the bits that changed. The old counter stays valid.
  var next = bits
  var i = 0
  while i < next.len and next[i]:
    next[i] = false
    inc result.flips
    inc i
  if i == next.len:
    next.add true
  else:
    next[i] = true
  inc result.flips
  result.bits = next

func counterFlips*(n: int): int {.raises: [].} =
  ## Total bit flips of `n` increments from zero. It is exactly 2n - popcount(n), so below 2n:
  ## an increment is amortized O(1) although a single one can flip every bit (ANALYSIS-AMORT-04).
  var bits: seq[bool]
  for _ in 1 .. n:
    let step = incrementBits(bits)
    bits = step.bits
    result += step.flips
