import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/patterns/state

# An event is drawn as (kind, argument): 0 coin (argument picks from valid and one invalid value),
# 1 select, 2 refund, 3 collect, 4 restock.
func toEvent(x: (int, int)): Event {.raises: [].} =
  case x[0]
  of 0: coin([10, 50, 100, 500, 7][x[1] mod 5])
  of 1: select()
  of 2: refund()
  of 3: collect()
  else: restock(x[1] - 1)   # argument 0 gives an invalid count

func eventsGen(): Gen[seq[(int, int)]] {.raises: [ValueError].} =
  seqOf(pair(intIn(0, 4), intIn(0, 4)), 0, 30)

func eventsOf(xs: seq[(int, int)]): seq[Event] {.raises: [].} =
  for x in xs: result.add toEvent(x)

# SPEC: GOF-STATE-01
test "GOF-STATE-01 Given any event sequence, when the machine runs, then money conservation and non-negative stock hold after every step":
  let outcome = check(pair(intIn(0, 3), eventsGen()), proc(p: (int, seq[(int, int)])): bool {.raises: [CatchableError].} =
    var m = newMachine(p[0])
    if not m.invariantHolds: return false
    for e in eventsOf(p[1]):
      let r = m.step(e)
      if r.isOk:
        m = r.value
        if not m.invariantHolds: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-STATE-02
test "GOF-STATE-02 Given a rejected event, when run, then the machine is unchanged and the rejection is listed with its index":
  let outcome = check(pair(intIn(0, 3), eventsGen()), proc(p: (int, seq[(int, int)])): bool {.raises: [CatchableError].} =
    let start = newMachine(p[0])
    var m = start
    var expectedRejected = 0
    for e in eventsOf(p[1]):
      let r = m.step(e)
      if r.isOk: m = r.value else: inc expectedRejected
    let rep = start.run(eventsOf(p[1]))
    rep.machine == m and rep.rejected.len == expectedRejected)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-STATE-03
test "GOF-STATE-03 Given an event log, when run twice from the same machine, then the reports are equal":
  let outcome = check(pair(intIn(0, 3), eventsGen()), proc(p: (int, seq[(int, int)])): bool {.raises: [CatchableError].} =
    let evs = eventsOf(p[1])
    let a = newMachine(p[0]).run(evs)
    let b = newMachine(p[0]).run(evs)
    a.machine == b.machine and a.rejected == b.rejected)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-STATE-04
test "GOF-STATE-04 Given 100 and 50 yen inserted, when selecting, then the item is sold and 30 yen change waits in the tray":
  let rep = newMachine(2).run([coin(100), coin(50), select()])
  check rep.rejected.len == 0
  check rep.machine.phase == pReturning
  check rep.machine.change == 30
  check rep.machine.stock == 1
  check rep.machine.sold == 1
  let done = rep.machine.run([collect()]).machine
  check done.phase == pIdle
  check done.returned == 30
  check done.invariantHolds

# SPEC: GOF-STATE-05
test "GOF-STATE-05 Given too little credit, when selecting, then veInsufficient and the credit stays":
  let m = newMachine(1).run([coin(100)]).machine
  check m.step(select()).error == veInsufficient
  check m.phase == pCredit
  check m.credit == 100

# SPEC: GOF-STATE-06
test "GOF-STATE-06 Given a machine returning change, when anything but collect arrives, then it is refused":
  let m = newMachine(3).run([coin(500), select()]).machine
  check m.phase == pReturning
  check m.step(coin(10)).error == veBusyReturning
  check m.step(select()).error == veBusyReturning
  check m.step(refund()).error == veBusyReturning
  check m.step(restock(2)).error == veNotIdle
  check m.step(collect()).isOk

# SPEC: GOF-STATE-07
test "GOF-STATE-07 Given an empty machine, when a coin arrives, then veSoldOut; after restocking it is accepted":
  let m = newMachine(0)
  check m.step(coin(100)).error == veSoldOut
  let stocked = m.step(restock(2)).value
  check stocked.stock == 2
  check stocked.step(coin(100)).isOk

# SPEC: GOF-STATE-08
test "GOF-STATE-08 Given credit, when refunded and collected, then the whole amount returns and nothing is sold":
  let m = newMachine(1).run([coin(50), coin(10), refund(), collect()]).machine
  check m.phase == pIdle
  check m.returned == 60
  check m.sold == 0
  check m.stock == 1
  check m.invariantHolds

# SPEC: GOF-STATE-09
test "GOF-STATE-09 Given a coin that is not accepted or a bad restock count, when applied, then it is refused":
  check newMachine(1).step(coin(7)).error == veBadCoin
  check newMachine(1).step(restock(0)).error == veBadCount
  check newMachine(1).step(collect()).error == veNothingToCollect
  check newMachine(1).step(select()).error == veNoCredit
