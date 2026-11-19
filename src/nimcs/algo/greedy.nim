## Greedy algorithms and the exchange argument, shown on interval scheduling: from a set of
## half-open intervals [start, finish), pick as many pairwise non-overlapping ones as possible.
##
## The greedy rule is "always take the interval that finishes first among those compatible with what
## is already chosen". It is correct because of an exchange argument (see the details page):
## any optimal schedule can be changed, one interval at a time, into the greedy one without losing size.
## Use a greedy rule only when such an argument exists; otherwise reach for dynamic programming
## (`knapsack`) or backtracking. The second example is the fractional knapsack, where items may be
## split and "best value per unit of weight first" is optimal (and wrong for whole items). Intervals touching at an end point do not overlap.

import std/[algorithm, options]

type
  Interval* = object
    ## The half-open range [start, finish). The fields are private so that the only way to build
    ## one is `interval`, which rejects empty and reversed ranges (TECH-GREEDY-04).
    startAt, finishAt: int

func interval*(start, finish: int): Option[Interval] {.raises: [].} =
  ## An interval must be non-empty: start < finish (TECH-GREEDY-04).
  if start < finish: some(Interval(startAt: start, finishAt: finish))
  else: none(Interval)

func start*(i: Interval): int {.raises: [].} = i.startAt
func finish*(i: Interval): int {.raises: [].} = i.finishAt

func overlaps*(a, b: Interval): bool {.raises: [].} =
  ## Do the half-open ranges share a point? Touching ranges do not (TECH-GREEDY-01).
  a.startAt < b.finishAt and b.startAt < a.finishAt

func scheduleIndices*(xs: openArray[Interval]): seq[int] {.raises: [].} =
  ## Indices into `xs` of a maximum set of pairwise non-overlapping intervals, ordered by time.
  ## Ties on the finish time are broken by earlier start, then by lower index, so the answer is
  ## deterministic and does not depend on any hash order (TECH-GREEDY-01 .. TECH-GREEDY-03).
  var keyed: seq[(int, int, int)] = @[]   # (finish, start, index): the order the rule scans in
  for i in 0 ..< xs.len:
    keyed.add (xs[i].finishAt, xs[i].startAt, i)
  keyed.sort()
  result = @[]
  var lastFinish = low(int)
  for (finish, start, index) in keyed:
    if start >= lastFinish:
      result.add index
      lastFinish = finish

func schedule*(xs: openArray[Interval]): seq[Interval] {.raises: [].} =
  ## The chosen intervals themselves.
  result = @[]
  for i in scheduleIndices(xs):
    result.add xs[i]

type
  Lot* = object
    ## An item that may be taken in part.
    weight*, value*: int

  Share* = object
    ## `taken` units of the weight of lot `index`, with 0 < taken < weight.
    index*, taken*: int

  FractionalPacking* = object
    ## `whole` lists the lots taken completely (ascending index); `partial` is the one lot cut
    ## short, if any. The total value is the fraction `valueNum / valueDen`, `valueDen` > 0.
    whole*: seq[int]
    partial*: Option[Share]
    valueNum*, valueDen*: int

func fractionalKnapsack*(lots: openArray[Lot]; capacity: int): Option[FractionalPacking] {.raises: [].} =
  ## Best value when lots may be split: take lots by decreasing value per unit of weight until the
  ## capacity is used up, cutting the last one (TECH-GREEDY-05 .. TECH-GREEDY-08). Lots of weight 0
  ## are always taken. None for a negative capacity, weight or value. Products of a weight and a
  ## value are assumed to fit `int`.
  if capacity < 0:
    return none(FractionalPacking)
  var items: seq[Lot] = @[]
  for lot in lots:
    if lot.weight < 0 or lot.value < 0:
      return none(FractionalPacking)
    items.add lot
  var whole: seq[int] = @[]
  var wholeValue = 0
  var heavy: seq[int] = @[]
  for i in 0 ..< items.len:
    if items[i].weight == 0:
      whole.add i
      wholeValue += items[i].value
    else:
      heavy.add i
  heavy.sort(proc(a, b: int): int {.raises: [].} =
    # a before b when value[a]/weight[a] > value[b]/weight[b], compared without division.
    let lhs = items[a].value * items[b].weight
    let rhs = items[b].value * items[a].weight
    if lhs > rhs: -1
    elif lhs < rhs: 1
    else: cmp(a, b))
  var remaining = capacity
  var partial = none(Share)
  var num = 0
  var den = 1
  for i in heavy:
    if items[i].weight <= remaining:
      whole.add i
      wholeValue += items[i].value
      remaining -= items[i].weight
    else:
      if remaining > 0:
        partial = some(Share(index: i, taken: remaining))
      break
  whole.sort()
  if partial.isSome:
    let cut = items[partial.get.index]
    den = cut.weight
    num = wholeValue * den + cut.value * partial.get.taken
  else:
    num = wholeValue
  some(FractionalPacking(whole: whole, partial: partial, valueNum: num, valueDen: den))
