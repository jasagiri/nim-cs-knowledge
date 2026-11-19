import std/unittest
import propcheck
import nimcs/patterns/observer

# Example domain: a price ticker. Each subscriber owns one slice of the Quotes state.
type
  Tick = object
    symbol: int
    price: int

  Quotes = object
    latest: seq[int]     ## last price per symbol 0..2, -1 when none
    high: int
    count: int
    audit: seq[string]

func `==`(a, b: Quotes): bool {.raises: [].} =
  a.latest == b.latest and a.high == b.high and a.count == b.count and a.audit == b.audit

func `$`(q: Quotes): string {.raises: [].} =
  "latest=" & $q.latest & " high=" & $q.high & " count=" & $q.count & " audit=" & $q.audit

func fresh(): Quotes {.raises: [].} = Quotes(latest: @[-1, -1, -1], high: 0, count: 0, audit: @[])

func trackLatest(q: Quotes; t: Tick): Quotes {.raises: [].} =
  result = q
  result.latest[t.symbol] = t.price

func trackHigh(q: Quotes; t: Tick): Quotes {.raises: [].} =
  result = q
  result.high = max(q.high, t.price)

func countTicks(q: Quotes; t: Tick): Quotes {.raises: [].} =
  result = q
  inc result.count

func logHigh(q: Quotes; t: Tick): Quotes {.raises: [].} =
  # Reads what the earlier subscribers wrote: the fold order is observable.
  result = q
  if t.price == q.high: result.audit.add "new high " & $t.price

type QBus = Bus[Quotes, Tick]

func fullBus(): QBus {.raises: [].} =
  initBus[Quotes, Tick]()
    .subscribe("latest", trackLatest)
    .subscribe("high", trackHigh)
    .subscribe("count", countTicks)
    .subscribe("audit", logHigh)

func ticksGen(): Gen[seq[(int, int)]] {.raises: [ValueError].} =
  seqOf(pair(intIn(0, 2), intIn(1, 50)), 0, 20)

func toTicks(xs: seq[(int, int)]): seq[Tick] {.raises: [].} =
  for x in xs: result.add Tick(symbol: x[0], price: x[1])

# SPEC: GOF-OBSERVER-01
test "GOF-OBSERVER-01 Given an event log, when replayed twice from the same state, then the results are equal":
  let outcome = check(ticksGen(), proc(xs: seq[(int, int)]): bool {.raises: [CatchableError].} =
    let log = toTicks(xs)
    fullBus().replay(fresh(), log) == fullBus().replay(fresh(), log))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-OBSERVER-02
test "GOF-OBSERVER-02 Given subscribers, when an event is published, then the result is the fold in subscription order":
  let outcome = check(pair(intIn(0, 2), intIn(1, 50)), proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let t = Tick(symbol: x[0], price: x[1])
    let byHand = logHigh(countTicks(trackHigh(trackLatest(fresh(), t), t), t), t)
    fullBus().publish(fresh(), t) == byHand)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-OBSERVER-03
test "GOF-OBSERVER-03 Given no subscribers, when events are published, then the state is unchanged":
  let outcome = check(ticksGen(), proc(xs: seq[(int, int)]): bool {.raises: [CatchableError].} =
    initBus[Quotes, Tick]().replay(fresh(), toTicks(xs)) == fresh())
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-OBSERVER-04
test "GOF-OBSERVER-04 Given a bus, when a subscriber is removed, then the rest still run in the same order and the old bus is intact":
  let bus = fullBus()
  let without = bus.unsubscribe("count")
  check without.ids == @["latest", "high", "audit"]
  check bus.ids == @["latest", "high", "count", "audit"]
  let outcome = check(ticksGen(), proc(xs: seq[(int, int)]): bool {.raises: [CatchableError].} =
    let log = toTicks(xs)
    let a = without.replay(fresh(), log)
    let b = bus.replay(fresh(), log)
    a.count == 0 and a.latest == b.latest and a.high == b.high and a.audit == b.audit)
  checkpoint describe(outcome)
  check outcome.passed
  check bus.unsubscribe("nobody").ids == bus.ids

# SPEC: GOF-OBSERVER-05
test "GOF-OBSERVER-05 Given two logs, when replayed in two steps or as one concatenated log, then the results are equal":
  let outcome = check(pair(ticksGen(), ticksGen()), proc(p: (seq[(int, int)], seq[(int, int)])): bool {.raises: [CatchableError].} =
    let a = toTicks(p[0])
    let b = toTicks(p[1])
    let bus = fullBus()
    bus.replay(bus.replay(fresh(), a), b) == bus.replay(fresh(), a & b))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-OBSERVER-06
test "GOF-OBSERVER-06 Given an id that is already subscribed, when subscribed again, then it replaces in place and nothing runs twice":
  let bus = fullBus().subscribe("count", countTicks)
  check bus.ids == @["latest", "high", "count", "audit"]
  let q = bus.publish(fresh(), Tick(symbol: 1, price: 5))
  check q.count == 1
  let swapped = bus.subscribe("count", proc(q: Quotes; t: Tick): Quotes {.noSideEffect, raises: [].} =
    result = q
    result.count += 10)
  check swapped.publish(fresh(), Tick(symbol: 1, price: 5)).count == 10

# SPEC: GOF-OBSERVER-07
test "GOF-OBSERVER-07 Given the four ticker subscribers, when ticks arrive, then the model shows latest, high, count and audit":
  let q = fullBus().replay(fresh(), [Tick(symbol: 0, price: 10), Tick(symbol: 1, price: 7), Tick(symbol: 0, price: 9)])
  check q.latest == @[9, 7, -1]
  check q.high == 10
  check q.count == 3
  check q.audit == @["new high 10"]
