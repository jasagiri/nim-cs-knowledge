## Fenwick tree (binary indexed tree): prefix sums with point updates over integers.
##
## Slot `i` (1-based) of a flat array stores the sum of the `lowbit(i)` elements that end at `i`,
## where `lowbit(i)` is the largest power of two dividing `i`. A prefix sum adds O(log n) slots
## (strip the lowest set bit each step); a point update adds to O(log n) slots (add the lowest set
## bit each step). Because a range sum is the difference of two prefix sums, the element type
## must have an inverse: this is the integers under `+`. Use it for running totals, rank counting
## and inversion counting; use `segment_tree` when the operation is only associative (min, gcd,
## string concatenation). A `FenwickTree` is a value: every update returns a new tree, so the
## copy of the flat array costs O(n); `addAll` applies many updates with one copy.
##
## Precondition for all sums: every prefix sum fits in `int`.

import std/options

type
  FenwickTree* = object
    slots: seq[int]    ## slots[0] is unused; slots[i] covers elements i - lowbit(i) ..< i (0-based)

func lowbit(i: int): int =
  i and -i

func len*(f: FenwickTree): int {.raises: [].} =
  ## Number of elements.
  f.slots.len - 1

func zeros*(n: int): Option[FenwickTree] {.raises: [].} =
  ## A tree of `n` zeros; none when `n` is negative.
  if n < 0: none(FenwickTree)
  else: some(FenwickTree(slots: newSeq[int](n + 1)))

func fromSeq*(items: openArray[int]): FenwickTree {.raises: [].} =
  ## Builds the tree in O(n): each slot is pushed once into the slot that also covers it.
  var slots = newSeq[int](items.len + 1)
  for i in 1 .. items.len:
    slots[i] += items[i - 1]
    let parent = i + lowbit(i)
    if parent <= items.len:
      slots[parent] += slots[i]
  FenwickTree(slots: slots)

func prefixSum*(f: FenwickTree; r: int): Option[int] {.raises: [].} =
  ## Sum of elements 0 ..< r; none unless 0 <= r <= len. `prefixSum(0)` is 0.
  if r < 0 or r > f.len: return none(int)
  var total = 0
  var i = r
  while i > 0:
    total += f.slots[i]
    i -= lowbit(i)
  some(total)

func rangeSum*(f: FenwickTree; l, r: int): Option[int] {.raises: [].} =
  ## Sum of elements l ..< r (half-open, like `segment_tree.query`); none unless 0 <= l <= r <= len.
  if l < 0 or l > r or r > f.len: return none(int)
  some(f.prefixSum(r).get - f.prefixSum(l).get)

func get*(f: FenwickTree; i: int): Option[int] {.raises: [].} =
  ## Element `i`; none when out of range.
  f.rangeSum(i, i + 1)

func add*(f: FenwickTree; i, delta: int): Option[FenwickTree] {.raises: [].} =
  ## A tree whose element `i` is increased by `delta`; none when `i` is out of range.
  if i < 0 or i >= f.len: return none(FenwickTree)
  var slots = f.slots
  var j = i + 1
  while j < slots.len:
    slots[j] += delta
    j += lowbit(j)
  some(FenwickTree(slots: slots))

func addAll*(f: FenwickTree; updates: openArray[(int, int)]): Option[FenwickTree] {.raises: [].} =
  ## Applies `(index, delta)` pairs with a single copy of the array. None, and no change, when any
  ## index is out of range.
  for (i, _) in updates:
    if i < 0 or i >= f.len: return none(FenwickTree)
  var slots = f.slots
  for (i, delta) in updates:
    var j = i + 1
    while j < slots.len:
      slots[j] += delta
      j += lowbit(j)
  some(FenwickTree(slots: slots))

func values*(f: FenwickTree): seq[int] {.raises: [].} =
  ## The elements in index order.
  for i in 0 ..< f.len:
    result.add f.get(i).get
