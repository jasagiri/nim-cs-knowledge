import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/patterns/cqrs

func commandOf(p: (int, (int, int))): Command {.raises: [].} =
  ## kind 0..2: receive for 0 and 1, ship for 2; sku from a tiny alphabet; quantity includes 0.
  let skus = ["a", "b", "c"]
  let kind = if p[0] < 2: ckReceive else: ckShip
  Command(kind: kind, sku: skus[p[1][0]], qty: p[1][1])

func commands(): Gen[seq[Command]] {.raises: [ValueError].} =
  seqOf(pair(intIn(0, 2), pair(intIn(0, 2), intIn(0, 6))).map(commandOf), 0, 25)

func lineKeysSortedUnique(lines: seq[StockLine]): bool {.raises: [].} =
  for i in 1 ..< lines.len:
    if not (lines[i - 1].sku < lines[i].sku): return false
  true

# SPEC: PAT-CQRS-01
test "PAT-CQRS-01 Given invalid commands, when decided, then each is rejected with its own error and no event":
  let stock = initStock().evolve(Event(kind: evReceived, sku: "a", qty: 5))
  let tooMany = stock.decide(Command(kind: ckShip, sku: "a", qty: 6))
  check tooMany.isErr
  check tooMany.error == ceInsufficientStock
  let unknown = stock.decide(Command(kind: ckShip, sku: "z", qty: 1))
  check unknown.error == ceInsufficientStock
  check stock.decide(Command(kind: ckReceive, sku: "a", qty: 0)).error == ceNonPositiveQty
  check stock.decide(Command(kind: ckShip, sku: "a", qty: -2)).error == ceNonPositiveQty
  check stock.decide(Command(kind: ckReceive, sku: "", qty: 1)).error == ceEmptySku

# SPEC: PAT-CQRS-01
test "PAT-CQRS-01 Given a command that is accepted, when decided, then exactly one event states what happened":
  let stock = initStock().evolve(Event(kind: evReceived, sku: "a", qty: 5))
  let shipped = stock.decide(Command(kind: ckShip, sku: "a", qty: 5))
  check shipped.isOk
  check shipped.value == @[Event(kind: evShipped, sku: "a", qty: 5)]

# SPEC: PAT-CQRS-02
test "PAT-CQRS-02 Given any commands, when submitted one by one, then every stock line stays positive, sorted and unique":
  let outcome = check(commands(), proc(cs: seq[Command]): bool {.raises: [CatchableError].} =
    var session = initSession()
    for c in cs:
      session = session.submit(c)
      for l in session.stock.lines:
        if l.qty <= 0: return false
      if not lineKeysSortedUnique(session.stock.lines): return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-CQRS-03
test "PAT-CQRS-03 Given any two event logs, when the dashboard is projected, then projecting the second onto the first equals projecting both":
  let outcome = check(pair(commands(), commands()), proc(p: (seq[Command], seq[Command])): bool {.raises: [CatchableError].} =
    let a = runAll(p[0]).events
    let b = runAll(p[1]).events
    dashboard(a & b) == continueDashboard(dashboard(a), b))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-CQRS-04
test "PAT-CQRS-04 Given any commands, when both read models are projected, then units on hand equal units received minus units shipped":
  let outcome = check(commands(), proc(cs: seq[Command]): bool {.raises: [CatchableError].} =
    let events = runAll(cs).events
    let d = dashboard(events)
    var onHand = 0
    for l in stockOf(events).lines: onHand += l.qty
    onHand == d.received - d.shipped and d.shipments >= 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-CQRS-05
test "PAT-CQRS-05 Given any commands, when the write-side stock is rebuilt from the events, then it equals the live stock":
  let outcome = check(commands(), proc(cs: seq[Command]): bool {.raises: [CatchableError].} =
    let s = runAll(cs)
    stockOf(s.events) == s.stock and s.events.len + s.rejected.len == cs.len)
  checkpoint describe(outcome)
  check outcome.passed
