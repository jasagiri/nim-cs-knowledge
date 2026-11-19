import std/[unittest, options]
import propcheck
import nimcs/algo/greedy

func ivs(): Gen[seq[(int, int)]] {.raises: [ValueError].} =
  seqOf(pair(intIn(0, 15), intIn(1, 6)), 0, 9)

func toIntervals(raw: seq[(int, int)]): seq[Interval] {.raises: [].} =
  result = @[]
  for (s, len) in raw:
    result.add interval(s, s + len).get

func disjoint(chosen: seq[Interval]): bool {.raises: [].} =
  for i in 0 ..< chosen.len:
    for j in i + 1 ..< chosen.len:
      if overlaps(chosen[i], chosen[j]):
        return false
  true

func bruteBest(xs: seq[Interval]): int {.raises: [].} =
  for mask in 0 ..< (1 shl xs.len):
    var pick: seq[Interval] = @[]
    for i in 0 ..< xs.len:
      if ((mask shr i) and 1) == 1:
        pick.add xs[i]
    if pick.len > result and disjoint(pick):
      result = pick.len

# SPEC: TECH-GREEDY-01
test "TECH-GREEDY-01 Given overlapping and touching intervals, when scheduling, then touching ones are compatible and overlapping ones are not":
  check not overlaps(interval(0, 3).get, interval(3, 5).get)
  check overlaps(interval(0, 3).get, interval(2, 5).get)
  let xs = [interval(1, 4).get, interval(3, 5).get, interval(0, 6).get,
            interval(5, 7).get, interval(8, 9).get, interval(5, 9).get]
  check scheduleIndices(xs) == @[0, 3, 4]
  check scheduleIndices(newSeq[Interval]()) == newSeq[int]()

# SPEC: TECH-GREEDY-02
test "TECH-GREEDY-02 Given any intervals, when scheduling, then the chosen ones are pairwise disjoint and no other interval can be added":
  let outcome = check(ivs(), proc(raw: seq[(int, int)]): bool {.raises: [CatchableError].} =
    let xs = toIntervals(raw)
    let chosen = schedule(xs)
    var maximal = disjoint(chosen)
    for x in xs:
      var clashes = false
      for c in chosen:
        clashes = clashes or overlaps(x, c)
      maximal = maximal and clashes
    maximal)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: TECH-GREEDY-03
test "TECH-GREEDY-03 Given any intervals, when scheduling, then the size equals the optimum over all subsets (exchange argument)":
  let outcome = check(ivs(), proc(raw: seq[(int, int)]): bool {.raises: [CatchableError].} =
    let xs = toIntervals(raw)
    scheduleIndices(xs).len == bruteBest(xs) and scheduleIndices(xs) == scheduleIndices(xs))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: TECH-GREEDY-04
test "TECH-GREEDY-04 Given an empty or reversed range, when building an interval, then the result is none":
  check interval(3, 3).isNone
  check interval(5, 2).isNone
  check interval(2, 5).get.start == 2
  check interval(2, 5).get.finish == 5
  # Interval(startAt: 5, finishAt: 5) does not compile outside the module: the fields are private.
  check not compiles(Interval(startAt: 5, finishAt: 5))

func lots(): Gen[seq[(int, int)]] {.raises: [ValueError].} =
  seqOf(pair(intIn(0, 9), intIn(0, 20)), 0, 8)

func toLots(raw: seq[(int, int)]): seq[Lot] {.raises: [].} =
  result = @[]
  for (w, v) in raw:
    result.add Lot(weight: w, value: v)

func bruteZeroOne(xs: seq[Lot]; capacity: int): int {.raises: [].} =
  for mask in 0 ..< (1 shl xs.len):
    var w = 0
    var v = 0
    for i in 0 ..< xs.len:
      if ((mask shr i) and 1) == 1:
        w += xs[i].weight
        v += xs[i].value
    if w <= capacity and v > result:
      result = v

# SPEC: TECH-GREEDY-05
test "TECH-GREEDY-05 Given the classic lots 60/10, 100/20, 120/30 and capacity 50, when packing fractionally, then the value is exactly 240":
  let r = fractionalKnapsack([Lot(weight: 10, value: 60), Lot(weight: 20, value: 100),
                              Lot(weight: 30, value: 120)], 50).get
  check r.whole == @[0, 1]
  check r.partial == some(Share(index: 2, taken: 20))
  check r.valueNum == 240 * r.valueDen
  check fractionalKnapsack(newSeq[Lot](), 5).get.valueNum == 0
  check fractionalKnapsack([Lot(weight: 0, value: 7), Lot(weight: 5, value: 1)], 0).get.whole == @[0]

# SPEC: TECH-GREEDY-06
test "TECH-GREEDY-06 Given any lots, when packing fractionally, then the weight fits and every taken lot has at least the ratio of every untaken one":
  let outcome = check(pair(lots(), intIn(0, 40)), proc(p: (seq[(int, int)], int)): bool {.raises: [CatchableError].} =
    let xs = toLots(p[0])
    let r = fractionalKnapsack(xs, p[1]).get
    var taken = newSeq[bool](xs.len)
    var used = 0
    for i in r.whole:
      taken[i] = true
      used += xs[i].weight
    var cutOk = true
    if r.partial.isSome:
      let sh = r.partial.get
      taken[sh.index] = true
      used += sh.taken
      cutOk = sh.taken > 0 and sh.taken < xs[sh.index].weight and sh.index notin r.whole
    var ratioOk = true
    var untakenWeight = false
    for t in 0 ..< xs.len:
      for u in 0 ..< xs.len:
        if taken[t] and not taken[u] and xs[t].weight > 0 and xs[u].weight > 0:
          ratioOk = ratioOk and xs[t].value * xs[u].weight >= xs[u].value * xs[t].weight
      if not taken[t] and xs[t].weight > 0:
        untakenWeight = true
    # If something with weight was left behind, the capacity is full.
    cutOk and ratioOk and used <= p[1] and (not untakenWeight or used == p[1]) and r.valueDen > 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: TECH-GREEDY-07
test "TECH-GREEDY-07 Given any lots, when packing fractionally, then the value is at least the best whole-item packing and the result is repeatable":
  let outcome = check(pair(lots(), intIn(0, 40)), proc(p: (seq[(int, int)], int)): bool {.raises: [CatchableError].} =
    let xs = toLots(p[0])
    let r = fractionalKnapsack(xs, p[1]).get
    r.valueNum >= bruteZeroOne(xs, p[1]) * r.valueDen and r == fractionalKnapsack(xs, p[1]).get)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: TECH-GREEDY-08
test "TECH-GREEDY-08 Given a negative capacity, weight or value, when packing fractionally, then the result is none":
  check fractionalKnapsack([Lot(weight: 1, value: 1)], -1).isNone
  check fractionalKnapsack([Lot(weight: -1, value: 1)], 3).isNone
  check fractionalKnapsack([Lot(weight: 1, value: -1)], 3).isNone
