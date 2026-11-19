import std/unittest
import propcheck
import nimcs/patterns/event_sourcing

func toEvents(raw: seq[(bool, int)]): seq[Event] {.raises: [].} =
  for (isDeposit, amount) in raw:
    result.add(if isDeposit: deposited(amount) else: withdrawn(amount))

func rawEvents(): Gen[seq[(bool, int)]] {.raises: [ValueError].} =
  seqOf(pair(boolean(), intIn(1, 500)), 0, 25)

func oracleBalance(events: seq[Event]): int {.raises: [].} =
  for e in events:
    case e.kind
    of evDeposited: result += e.amount
    of evWithdrawn: result -= e.amount

# SPEC: PAT-EVENTSOURCING-01
test "PAT-EVENTSOURCING-01 Given any log and event, when appended, then replaying the new log equals applying the event to the old state":
  let outcome = check(pair(rawEvents(), pair(boolean(), intIn(1, 500))),
    proc(p: (seq[(bool, int)], (bool, int))): bool {.raises: [CatchableError].} =
      let log = toEvents(p[0])
      let e = if p[1][0]: deposited(p[1][1]) else: withdrawn(p[1][1])
      replay(log.appended(e)) == replay(log).apply(e) and replay(log) == replay(log))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-EVENTSOURCING-02
test "PAT-EVENTSOURCING-02 Given any log and any cut, when a snapshot at the cut is extended with the tail, then it equals the full replay":
  let outcome = check(pair(rawEvents(), intIn(0, 30)),
    proc(p: (seq[(bool, int)], int)): bool {.raises: [CatchableError].} =
      let log = toEvents(p[0])
      let cut = min(p[1], log.len)
      replayFrom(snapshotAt(log, cut), log[cut .. ^1]) == replay(log))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-EVENTSOURCING-03
test "PAT-EVENTSOURCING-03 Given any log, when replayed, then the version is its length and the balance is deposits minus withdrawals":
  let outcome = check(rawEvents(), proc(raw: seq[(bool, int)]): bool {.raises: [CatchableError].} =
    let log = toEvents(raw)
    let a = replay(log)
    a.version == log.len and a.balance == oracleBalance(log))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-EVENTSOURCING-04
test "PAT-EVENTSOURCING-04 Given a log, when an event is appended, then the old log is unchanged and the new one is one longer":
  let outcome = check(rawEvents(), proc(raw: seq[(bool, int)]): bool {.raises: [CatchableError].} =
    let log = toEvents(raw)
    let before = log
    let longer = log.appended(deposited(7))
    log == before and longer.len == log.len + 1 and longer[^1] == deposited(7))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-EVENTSOURCING-05
test "PAT-EVENTSOURCING-05 Given a log, when snapshotAt is asked for the start or beyond the end, then it gives the empty account or the full replay":
  let outcome = check(rawEvents(), proc(raw: seq[(bool, int)]): bool {.raises: [CatchableError].} =
    let log = toEvents(raw)
    snapshotAt(log, 0) == initAccount() and snapshotAt(log, -3) == initAccount() and
      snapshotAt(log, log.len + 5) == replay(log))
  checkpoint describe(outcome)
  check outcome.passed
