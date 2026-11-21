import std/[unittest, sets, sequtils]
import propcheck
import nimcs/patterns/transactional_outbox
import nimcs/patterns/idempotent_command

func msgs(n: int): seq[(string, string)] {.raises: [].} =
  for i in 0 ..< n: result.add ("topic", "p" & $i)

func ids(o: Outbox): seq[string] {.raises: [].} =
  for m in o.pending: result.add m.id

func statusOf(b: bool): DeliveryStatus {.raises: [].} = (if b: dsDelivered else: dsFailed)

func results(o: Outbox; flags: seq[bool]): seq[Delivery] {.raises: [].} =
  ## Delivery results for the pending messages, `flags[i]` for the i-th (false past the end).
  for i, m in o.pending:
    result.add delivery(m.id, statusOf(i < flags.len and flags[i]))

# SPEC: PAT-TXOUTBOX-01
test "PAT-TXOUTBOX-01 Given a unit, when a change is recorded with messages, then the new state and the messages arrive together with sequential unique ids":
  let outcome = check(pair(intIn(0, 1000), pair(intIn(0, 6), intIn(0, 6))), proc(x: (int, (int, int))): bool {.raises: [CatchableError].} =
    let u0 = initUnit(x[0], initOutbox("acct"))
    let u1 = u0.record(x[0] + 1, msgs(x[1][0]))
    let u2 = u1.record(x[0] + 2, msgs(x[1][1]))
    var expected: seq[string]
    for i in 0 ..< x[1][0] + x[1][1]: expected.add "acct-" & $i
    u1.state == x[0] + 1 and u1.outbox.len == x[1][0] and u2.state == x[0] + 2 and
      u2.outbox.ids == expected and u2.outbox.nextSequence == expected.len and
      u2.outbox.ids.toHashSet.len == expected.len and u0.outbox.len == 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TXOUTBOX-02
test "PAT-TXOUTBOX-02 Given a recorded change, when the messages are read, then they keep topic, payload and order":
  let u = initUnit("s0", initOutbox("p")).record("s1", [("paid", "42"), ("shipped", "7")])
  check u.outbox.pending[0] == Message(id: "p-0", topic: "paid", payload: "42")
  check u.outbox.pending[1] == Message(id: "p-1", topic: "shipped", payload: "7")

# SPEC: PAT-TXOUTBOX-03
test "PAT-TXOUTBOX-03 Given any outbox, when a batch is asked, then it is the oldest messages up to the count and the outbox is unchanged":
  let outcome = check(pair(intIn(0, 10), intIn(-2, 14)), proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let o = initUnit(0, initOutbox("p")).record(1, msgs(x[0])).outbox
    let batch = o.nextBatch(x[1])
    let n = max(0, min(x[1], x[0]))
    batch.len == n and batch == o.pending[0 ..< n] and o.nextBatch(x[1]) == batch)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TXOUTBOX-04
test "PAT-TXOUTBOX-04 Given any delivery results, when settled, then exactly the undelivered messages remain, in order":
  let outcome = check(pair(intIn(0, 10), seqOf(boolean(), 0, 10)), proc(x: (int, seq[bool])): bool {.raises: [CatchableError].} =
    let o = initUnit(0, initOutbox("p")).record(1, msgs(x[0])).outbox
    let rest = o.settle(o.results(x[1]))
    var expected: seq[Message]
    for i, m in o.pending:
      if not (i < x[1].len and x[1][i]): expected.add m
    rest.pending == expected and rest.nextSequence == o.nextSequence)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TXOUTBOX-05
test "PAT-TXOUTBOX-05 Given any results, when they are settled twice, then the outbox equals settling once; all failures change nothing":
  let outcome = check(pair(intIn(0, 10), seqOf(boolean(), 0, 10)), proc(x: (int, seq[bool])): bool {.raises: [CatchableError].} =
    let o = initUnit(0, initOutbox("p")).record(1, msgs(x[0])).outbox
    let r = o.results(x[1])
    let once = o.settle(r)
    let none = o.settle(o.results(@[]))
    once.settle(r) == once and none == o and o.settle([]) == o and
      o.settle(o.results(newSeqWith(x[0], true))).len == 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TXOUTBOX-06
test "PAT-TXOUTBOX-06 Given delivered messages, when new messages are recorded, then their ids are never reused":
  let outcome = check(pair(intIn(0, 8), pair(intIn(0, 8), seqOf(boolean(), 0, 8))), proc(x: (int, (int, seq[bool]))): bool {.raises: [CatchableError].} =
    let u1 = initUnit(0, initOutbox("p")).record(1, msgs(x[0]))
    let settled = u1.outbox.settle(u1.outbox.results(x[1][1]))
    let u2 = initUnit(2, settled).record(3, msgs(x[1][0]))
    let issued = u1.outbox.ids.toHashSet
    var fresh: seq[string]
    for i in x[0] ..< x[0] + x[1][0]: fresh.add "p-" & $i
    let added = u2.outbox.ids[u2.outbox.len - x[1][0] .. ^1]
    added == fresh and fresh.allIt(it notin issued) and u2.outbox.nextSequence == x[0] + x[1][0])
  checkpoint describe(outcome)
  check outcome.passed

# The shell and the receiver. The receiver is an account that applies each message once, keyed by
# the message id (idempotent_command): a deposit of the payload's amount.
func apply(l: Ledger; m: Message): Ledger {.raises: [].} =
  l.handle(Command(key: m.id, kind: ckDeposit, amount: m.payload.len)).ledger

# SPEC: PAT-TXOUTBOX-07
test "PAT-TXOUTBOX-07 Given rounds in which acknowledgements are lost, when the relay retries, then every message is applied exactly once and the outbox ends empty":
  let outcome = check(pair(intIn(0, 8), seqOf(pair(boolean(), boolean()), 0, 12)), proc(x: (int, seq[(bool, bool)])): bool {.raises: [CatchableError].} =
    let all = initUnit(0, initOutbox("p")).record(1, msgs(x[0])).outbox
    var o = all
    var receiver = initLedger()
    # Each round: send a batch of 3; for message i, `sent` decides whether it arrives and `acked`
    # whether the acknowledgement comes back. Rounds past the plan are all good.
    for round in 0 ..< x[1].len + 6:
      let batch = o.nextBatch(3)
      var rs: seq[Delivery]
      for i, m in batch:
        let (sent, acked) = if round < x[1].len and i == 0: x[1][round] else: (true, true)
        if sent: receiver = receiver.apply(m)
        rs.add delivery(m.id, statusOf(sent and acked))
      o = o.settle(rs)
    var once = initLedger()
    for m in all.pending: once = once.apply(m)
    o.len == 0 and receiver.balance == once.balance and receiver.entries.len == x[0])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-TXOUTBOX-02
test "PAT-TXOUTBOX-02 Given messages that differ in one field, when they are compared, then they are unequal":
  let m = Message(id: "p-0", topic: "paid", payload: "42")
  check m == Message(id: "p-0", topic: "paid", payload: "42")
  check m != Message(id: "p-1", topic: "paid", payload: "42")
  check m != Message(id: "p-0", topic: "shipped", payload: "42")
  check m != Message(id: "p-0", topic: "paid", payload: "43")

# SPEC: PAT-TXOUTBOX-05
test "PAT-TXOUTBOX-05 Given outboxes that differ in one part, when they are compared, then they are unequal":
  let o = initOutbox("p")
  check o == initOutbox("p")
  check o != initOutbox("q")
  check o.enqueue("t", "x") != o
  check o.enqueue("t", "x") == o.enqueue("t", "x")
  check o.enqueue("t", "x") != o.enqueue("t", "y")
  # same pending messages, different next sequence: settle drops a message without lowering it
  let two = o.enqueue("t", "x").enqueue("t", "y")
  let rest = two.settle([delivery("p-0", dsDelivered)])
  check rest != two.settle([delivery("p-1", dsDelivered)])
  check rest.nextSequence == 2
  check rest != initOutbox("p").enqueue("t", "y")
