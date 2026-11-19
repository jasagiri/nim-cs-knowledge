## 0/1 knapsack: choose a subset of items, each at most once, to maximise total value without
## exceeding a weight capacity.
##
## Use it when items are indivisible and capacity is a small integer; the table has
## `items * (capacity + 1)` cells, so it is pseudo-polynomial (reach for branch and bound or an
## approximation scheme when the capacity is huge). When items may be split, the greedy
## value-per-weight rule is optimal instead (`fractionalKnapsack` in `greedy`). Totals are assumed not to overflow
## `int`: that is the caller's precondition, not checked here.

import std/options

const maxTableCells*: int = 100_000_000
  ## Largest `(items + 1) * (capacity + 1)` the table may have (800 MB of `int`); beyond it
  ## `knapsack` returns none instead of exhausting memory or overflowing the size.

type
  Item* = object
    weight*, value*: int

  Packing* = object
    ## `chosen` holds the indices of the picked items, ascending.
    value*: int
    weight*: int
    chosen*: seq[int]

func item*(weight, value: int): Option[Item] {.raises: [].} =
  ## An item needs a non-negative weight and a non-negative value (DP-KNAP-04).
  if weight < 0 or value < 0: none(Item)
  else: some(Item(weight: weight, value: value))

func knapsack*(items: openArray[Item]; capacity: int): Option[Packing] {.raises: [].} =
  ## Best packing. None when `capacity` < 0 or an item has a negative weight or value (DP-KNAP-04),
  ## or when the table would exceed `maxTableCells` (DP-KNAP-06).
  ## Among equally valuable packings it returns the one found by walking back from the last item
  ## and keeping an item only when leaving it out would be strictly worse (DP-KNAP-05).
  if capacity < 0 or capacity >= maxTableCells div (items.len + 1):
    return none(Packing)
  for it in items:
    if it.weight < 0 or it.value < 0:
      return none(Packing)
  let w = capacity + 1
  var table = newSeq[int]((items.len + 1) * w)
  for i in 1 .. items.len:
    let it = items[i - 1]
    for c in 0 .. capacity:
      let skip = table[(i - 1) * w + c]
      table[i * w + c] =
        if it.weight <= c: max(skip, table[(i - 1) * w + c - it.weight] + it.value)
        else: skip
  var c = capacity
  var picked: seq[int] = @[]
  var totalWeight = 0
  for i in countdown(items.len, 1):
    if table[i * w + c] != table[(i - 1) * w + c]:
      picked.add i - 1
      c -= items[i - 1].weight
      totalWeight += items[i - 1].weight
  var chosen = newSeq[int](picked.len)
  for k in 0 ..< picked.len:
    chosen[k] = picked[picked.len - 1 - k]
  some(Packing(value: table[items.len * w + capacity], weight: totalWeight, chosen: chosen))
