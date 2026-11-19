## State: the state is an object variant and a transition is a pure function.
##
## The OO pattern gives each state a class so that `insertCoin()`, `select()` ... behave
## differently per state without `if`s on a flag. In Nim the states are the cases of one object
## variant (so fields such as `credit` exist only where they mean something), and behaviour is
## `step(state, event)`: an exhaustive `case` on the phase, then on the event. An event the
## current state does not accept is a `Result` error and leaves the state as it was. The example
## is a one-product vending machine, priced in yen, which also tracks money conservation:
## everything inserted is either sold, returned, or still held. Use it for protocols, workflows
## and UI modes; when states multiply, keep one `case` per phase in its own func.

import nimcs/fp/result

const
  Price* = 120
  Coins* = [10, 50, 100, 500]

type
  Phase* = enum
    pIdle, pCredit, pReturning

  Machine* = object
    stock*: int
    inserted*: int    ## total money ever accepted
    sold*: int        ## items sold
    returned*: int    ## money handed back and collected
    case phase*: Phase
    of pIdle: discard
    of pCredit:
      credit*: int
    of pReturning:
      change*: int    ## money waiting in the tray (change or refund)

  EventKind* = enum
    evCoin, evSelect, evRefund, evCollect, evRestock

  Event* = object
    case kind*: EventKind
    of evCoin: value*: int
    of evRestock: count*: int
    of evSelect, evRefund, evCollect: discard

  VendError* = enum
    veBadCoin, veSoldOut, veNoCredit, veInsufficient, veBusyReturning, veNothingToCollect,
    veNotIdle, veBadCount

  RunReport* = object
    machine*: Machine
    rejected*: seq[(int, VendError)]   ## (index in the event list, reason)

func coin*(v: int): Event {.raises: [].} = Event(kind: evCoin, value: v)
func select*(): Event {.raises: [].} = Event(kind: evSelect)
func refund*(): Event {.raises: [].} = Event(kind: evRefund)
func collect*(): Event {.raises: [].} = Event(kind: evCollect)
func restock*(n: int): Event {.raises: [].} = Event(kind: evRestock, count: n)

func `==`*(a, b: Machine): bool {.raises: [].} =
  if a.phase != b.phase: return false
  if a.stock != b.stock or a.inserted != b.inserted or a.sold != b.sold or
      a.returned != b.returned: return false
  case a.phase
  of pIdle: true
  of pCredit: a.credit == b.credit
  of pReturning: a.change == b.change

func newMachine*(stock: int): Machine {.raises: [].} =
  Machine(phase: pIdle, stock: max(0, stock), inserted: 0, sold: 0, returned: 0)

func held*(m: Machine): int {.raises: [].} =
  ## Money the machine holds on behalf of the customer.
  case m.phase
  of pIdle: 0
  of pCredit: m.credit
  of pReturning: m.change

func invariantHolds*(m: Machine): bool {.raises: [].} =
  ## Money conservation, no negative counts.
  m.stock >= 0 and m.held >= 0 and m.sold >= 0 and m.returned >= 0 and
    m.inserted == m.sold * Price + m.returned + m.held

func accepted(v: int): bool {.raises: [].} =
  for c in Coins:
    if c == v: return true

func withPhaseCredit(m: Machine; credit: int): Machine {.raises: [].} =
  Machine(phase: pCredit, credit: credit, stock: m.stock, inserted: m.inserted,
          sold: m.sold, returned: m.returned)

func withPhaseReturning(m: Machine; change: int): Machine {.raises: [].} =
  Machine(phase: pReturning, change: change, stock: m.stock, inserted: m.inserted,
          sold: m.sold, returned: m.returned)

func withPhaseIdle(m: Machine): Machine {.raises: [].} =
  Machine(phase: pIdle, stock: m.stock, inserted: m.inserted, sold: m.sold, returned: m.returned)

func step*(m: Machine; e: Event): Result[Machine, VendError] {.raises: [].} =
  ## The transition table. Every (phase, event) pair is decided here, none by default.
  case m.phase
  of pIdle:
    case e.kind
    of evCoin:
      if not accepted(e.value): return err(Machine, veBadCoin)
      if m.stock == 0: return err(Machine, veSoldOut)
      var n = m.withPhaseCredit(e.value)
      n.inserted += e.value
      ok(n, VendError)
    of evSelect, evRefund: err(Machine, veNoCredit)
    of evCollect: err(Machine, veNothingToCollect)
    of evRestock:
      if e.count < 1: return err(Machine, veBadCount)
      var n = m
      n.stock += e.count
      ok(n, VendError)
  of pCredit:
    case e.kind
    of evCoin:
      if not accepted(e.value): return err(Machine, veBadCoin)
      var n = m.withPhaseCredit(m.credit + e.value)
      n.inserted += e.value
      ok(n, VendError)
    of evSelect:
      if m.credit < Price: return err(Machine, veInsufficient)
      var n = m.withPhaseReturning(m.credit - Price)
      dec n.stock
      inc n.sold
      ok(n, VendError)
    of evRefund: ok(m.withPhaseReturning(m.credit), VendError)
    of evCollect: err(Machine, veNothingToCollect)
    of evRestock: err(Machine, veNotIdle)
  of pReturning:
    case e.kind
    of evCollect:
      var n = m.withPhaseIdle()
      n.returned += m.change
      ok(n, VendError)
    of evCoin, evSelect, evRefund: err(Machine, veBusyReturning)
    of evRestock: err(Machine, veNotIdle)

func run*(m: Machine; events: openArray[Event]): RunReport {.raises: [].} =
  ## Feeds the events in order. A rejected event leaves the machine unchanged and is listed.
  result = RunReport(machine: m, rejected: @[])
  for i, e in events:
    let r = step(result.machine, e)
    if r.isOk: result.machine = r.value
    else: result.rejected.add (i, r.error)
