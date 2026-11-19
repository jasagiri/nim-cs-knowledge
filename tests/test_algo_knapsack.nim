import std/[unittest, options]
import propcheck
import nimcs/algo/knapsack

func items(): Gen[seq[(int, int)]] {.raises: [ValueError].} =
  seqOf(pair(intIn(0, 9), intIn(0, 20)), 0, 8)

func toItems(raw: seq[(int, int)]): seq[Item] {.raises: [].} =
  result = @[]
  for (w, v) in raw:
    result.add Item(weight: w, value: v)

func bruteBest(xs: seq[Item]; capacity: int): int {.raises: [].} =
  for mask in 0 ..< (1 shl xs.len):
    var w = 0
    var v = 0
    for i in 0 ..< xs.len:
      if ((mask shr i) and 1) == 1:
        w += xs[i].weight
        v += xs[i].value
    if w <= capacity and v > result:
      result = v

# SPEC: DP-KNAP-01
test "DP-KNAP-01 Given a classic instance, when packing, then the optimum value and items are the hand-worked ones":
  let xs = [Item(weight: 1, value: 1), Item(weight: 3, value: 4), Item(weight: 4, value: 5),
            Item(weight: 5, value: 7)]
  let r = knapsack(xs, 7).get
  check r.value == 9
  check r.chosen == @[1, 2]
  check r.weight == 7
  check knapsack(xs, 0).get.value == 0
  check knapsack(newSeq[Item](), 10).get == Packing(value: 0, weight: 0, chosen: @[])

# SPEC: DP-KNAP-02
test "DP-KNAP-02 Given any instance, when packing, then the value equals the best over all subsets":
  let outcome = check(pair(items(), intIn(0, 30)), proc(p: (seq[(int, int)], int)): bool {.raises: [CatchableError].} =
    let xs = toItems(p[0])
    knapsack(xs, p[1]).get.value == bruteBest(xs, p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: DP-KNAP-03
test "DP-KNAP-03 Given any instance, when packing, then the chosen items are ascending, fit the capacity and add up to the value":
  let outcome = check(pair(items(), intIn(0, 30)), proc(p: (seq[(int, int)], int)): bool {.raises: [CatchableError].} =
    let xs = toItems(p[0])
    let r = knapsack(xs, p[1]).get
    var w = 0
    var v = 0
    var ascending = true
    for k in 0 ..< r.chosen.len:
      let i = r.chosen[k]
      if i < 0 or i >= xs.len or (k > 0 and r.chosen[k - 1] >= i):
        ascending = false
      else:
        w += xs[i].weight
        v += xs[i].value
    ascending and w <= p[1] and w == r.weight and v == r.value)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: DP-KNAP-04
test "DP-KNAP-04 Given a negative capacity, weight or value, when packing or building an item, then the result is none":
  check item(-1, 3).isNone
  check item(3, -1).isNone
  check item(0, 0).isSome
  check knapsack([Item(weight: 1, value: 1)], -1).isNone
  check knapsack([Item(weight: -1, value: 1)], 5).isNone
  check knapsack([Item(weight: 1, value: -1)], 5).isNone

# SPEC: DP-KNAP-05
test "DP-KNAP-05 Given an instance, when packing twice or with more capacity, then the answer is repeatable and never worse":
  let outcome = check(pair(items(), intIn(0, 30)), proc(p: (seq[(int, int)], int)): bool {.raises: [CatchableError].} =
    let xs = toItems(p[0])
    knapsack(xs, p[1]) == knapsack(xs, p[1]) and
      knapsack(xs, p[1] + 1).get.value >= knapsack(xs, p[1]).get.value)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: DP-KNAP-06
test "DP-KNAP-06 Given a capacity whose table would exceed maxTableCells, when packing, then the result is none":
  let xs = [Item(weight: 1, value: 1)]
  check knapsack(xs, high(int)).isNone
  check knapsack(xs, maxTableCells).isNone
  check knapsack(newSeq[Item](), maxTableCells).isNone
  check knapsack(xs, 1000).isSome   # inside the bound (larger ones would allocate GBs in a test)
