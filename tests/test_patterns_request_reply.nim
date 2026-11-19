import std/[options, unittest]
import propcheck
import nimcs/patterns/actor
import nimcs/patterns/request_reply

# The context kept with a pending request is a label; here it is the request's own number so that
# a settlement can be checked against the request it belongs to.
type Ledg = Ledger[int]

func asks(n: int; now = 0; timeout = 10): (Ledg, seq[CorrelationId]) {.raises: [].} =
  var l = initLedger[int]()
  var ids: seq[CorrelationId]
  for i in 0 ..< n:
    let a = l.ask(Address(7), "q" & $i, i, now, timeout)
    l = a.ledger
    ids.add a.request.id
  (l, ids)

# SPEC: PAT-REQREPLY-01
test "PAT-REQREPLY-01 Given any mix of replies, timeouts, duplicates and unknown ids, when every leftover request is timed out, then each request settled exactly once":
  let outcome = check(pair(intIn(1, 8), seqOf(pair(boolean(), intIn(0, 10)), 0, 30)),
      proc(x: (int, seq[(bool, int)])): bool {.raises: [CatchableError].} =
    let (n, events) = x
    var (l, ids) = asks(n)
    var settled = newSeq[int](n)
    for (isReply, k) in events:
      let id = if k < n: ids[k] else: CorrelationId(1000 + k)    # k >= n is an id nobody asked
      if isReply:
        let (l2, got) = l.onReply(Reply[string](id: id, body: "a"))
        l = l2
        if got.isSome:
          inc settled[got.get]
      else:
        let (l2, got) = l.onTimeout(id)
        l = l2
        if got.isSome:
          inc settled[got.get]
    for i in 0 ..< n:
      let (l2, got) = l.onTimeout(ids[i])
      l = l2
      if got.isSome: inc settled[got.get]
    var exactlyOnce = true
    for c in settled:
      if c != 1: exactlyOnce = false
    exactlyOnce and l.pendingCount == 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-REQREPLY-02
test "PAT-REQREPLY-02 Given a request that already timed out or was answered, when a reply or timeout arrives, then it is dropped and the ledger is unchanged":
  let (l, ids) = asks(3)
  let (afterTimeout, first) = l.onTimeout(ids[1])
  check first == some(1)
  let (lateReply, dropped) = afterTimeout.onReply(Reply[string](id: ids[1], body: "late"))
  check dropped.isNone
  check lateReply.pendingCount == 2
  check not lateReply.isPending(ids[1])
  let (afterReply, answered) = l.onReply(Reply[string](id: ids[0], body: "a"))
  check answered == some(0)
  check afterReply.onReply(Reply[string](id: ids[0], body: "again"))[1].isNone
  check afterReply.onTimeout(ids[0])[1].isNone
  check afterReply.onTimeout(ids[0])[0].pendingCount == afterReply.pendingCount

# SPEC: PAT-REQREPLY-03
test "PAT-REQREPLY-03 Given a ledger, when requests are made and settled, then correlation ids are distinct and increasing and never reused":
  let outcome = check(seqOf(boolean(), 1, 20), proc(settleEach: seq[bool]): bool {.raises: [CatchableError].} =
    var l = initLedger[int]()
    var seen: seq[int]
    for settle in settleEach:
      let a = l.ask(Address(0), "q", 0, 0, 5)
      l = a.ledger
      seen.add int(a.request.id)
      if settle: l = l.onTimeout(a.request.id)[0]
    var increasing = true
    for i in 1 ..< seen.len:
      if seen[i] <= seen[i - 1]: increasing = false
    increasing)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-REQREPLY-04
test "PAT-REQREPLY-04 Given requests with deadlines, when the host asks what is due at a tick, then exactly the pending requests whose deadline has passed are listed in id order":
  let outcome = check(pair(seqOf(pair(intIn(0, 20), intIn(0, 20)), 1, 10), intIn(0, 45)),
      proc(x: (seq[(int, int)], int)): bool {.raises: [CatchableError].} =
    let (reqs, tick) = x
    var l = initLedger[int]()
    var expected: seq[int]
    var deadlinesRight = true
    for i, (now, timeout) in reqs:
      let a = l.ask(Address(0), "q", i, now, timeout)
      l = a.ledger
      if a.deadline != now + timeout: deadlinesRight = false
      if now + timeout <= tick: expected.add int(a.request.id)
    var got: seq[int]
    for id in l.dueAt(tick): got.add int(id)
    got == expected and deadlinesRight)
  checkpoint describe(outcome)
  check outcome.passed
  check initLedger[int]().ask(Address(0), "q", 0, high(int) - 1, 100).deadline == high(int)

# SPEC: PAT-REQREPLY-05
test "PAT-REQREPLY-05 Given a ledger, when a request is added or settled, then the earlier ledger is unchanged":
  let (l, ids) = asks(4)
  let bigger = l.ask(Address(0), "q", 9, 0, 1).ledger
  let (smaller, _) = l.onTimeout(ids[2])
  check l.pendingCount == 4
  check bigger.pendingCount == 5
  check smaller.pendingCount == 3
  check l.isPending(ids[2])

# SPEC: PAT-REQREPLY-06
test "PAT-REQREPLY-06 Given several pending requests, when one reply arrives, then only the request with that id is settled":
  let outcome = check(pair(intIn(2, 8), intIn(0, 7)), proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let (n, k) = x
    let (l, ids) = asks(n)
    let pick = k mod n
    let req = Request[string](id: ids[pick], replyTo: Address(7), body: "q")
    let (after, got) = l.onReply(req.replyWith("a"))
    var others = true
    for i in 0 ..< n:
      if i != pick and not after.isPending(ids[i]): others = false
    got == some(pick) and others and after.pendingCount == n - 1)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-REQREPLY-07
test "PAT-REQREPLY-07 Given a request, when it is made, then it carries the correlation id, the reply-to address and the body, and the reply carries the same id":
  let a = initLedger[int]().ask(Address(3), "ping", 0, 5, 20)
  check a.request.replyTo == Address(3)
  check a.request.body == "ping"
  check a.deadline == 25
  check a.request.replyWith("pong").id == a.request.id
  check a.request.replyWith("pong").body == "pong"
