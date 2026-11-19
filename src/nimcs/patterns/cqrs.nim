## CQRS: commands are decided into events on one side, read models are folds of the same events on the other.
##
## Command and query responsibility segregation splits a system in two. The write side takes a
## command, checks it against the current state and answers with events or a reason for refusing;
## it keeps only the state needed to decide. The read side never decides anything: each read model
## is a projection, a fold over the events, shaped for the question it answers. Here both sides
## consume the same event log (CQRS does not require event sourcing; the log is what makes the
## projections easy to state), so read models can be added or rebuilt at will. The example is a
## small warehouse: receive and ship units, with a stock table (write side) and a dashboard
## (read side).

import std/algorithm
import nimcs/fp/result

type
  StockLine* = object
    sku*: string
    qty*: int

  Stock* = object
    ## Write-side state: one line per sku that is on hand, sorted by sku, never a zero line.
    lines*: seq[StockLine]

  CommandKind* = enum
    ckReceive, ckShip

  Command* = object
    kind*: CommandKind
    sku*: string
    qty*: int

  EventKind* = enum
    evReceived, evShipped

  Event* = object
    kind*: EventKind
    sku*: string
    qty*: int

  CommandError* = enum
    ceNonPositiveQty, ceEmptySku, ceInsufficientStock

  Session* = object
    ## The application service state: current stock, the event log, and the refusals.
    stock*: Stock
    events*: seq[Event]
    rejected*: seq[CommandError]

  Dashboard* = object
    ## A read model: totals only, no per-sku detail.
    received*: int
    shipped*: int
    shipments*: int

# ── write side ─────────────────────────────────────────────────────────────

func initStock*(): Stock {.raises: [].} = Stock(lines: @[])

func qtyOf*(stock: Stock; sku: string): int {.raises: [].} =
  for l in stock.lines:
    if l.sku == sku: return l.qty
  0

func evolve*(stock: Stock; e: Event): Stock {.raises: [].} =
  ## Applies a fact to the stock. Lines whose quantity becomes zero disappear, so equal stocks
  ## are equal values. An event that `decide` never produced (shipping more than is on hand)
  ## would leave a negative line; the guard against that lives in `decide`, not here.
  let delta = if e.kind == evReceived: e.qty else: -e.qty
  var lines: seq[StockLine]
  var seen = false
  for l in stock.lines:
    if l.sku == e.sku:
      seen = true
      if l.qty + delta != 0: lines.add StockLine(sku: l.sku, qty: l.qty + delta)
    else:
      lines.add l
  if not seen and delta != 0: lines.add StockLine(sku: e.sku, qty: delta)
  lines.sort(proc(a, b: StockLine): int = cmp(a.sku, b.sku))
  Stock(lines: lines)

func decide*(stock: Stock; cmd: Command): Result[seq[Event], CommandError] {.raises: [].} =
  ## Validates a command against the stock. It returns the events that record what happens, or
  ## the first reason it must be refused; it changes nothing.
  if cmd.sku.len == 0:
    return err(seq[Event], ceEmptySku)
  if cmd.qty <= 0:
    return err(seq[Event], ceNonPositiveQty)
  case cmd.kind
  of ckReceive:
    ok(@[Event(kind: evReceived, sku: cmd.sku, qty: cmd.qty)], CommandError)
  of ckShip:
    if stock.qtyOf(cmd.sku) < cmd.qty:
      err(seq[Event], ceInsufficientStock)
    else:
      ok(@[Event(kind: evShipped, sku: cmd.sku, qty: cmd.qty)], CommandError)

func initSession*(): Session {.raises: [].} =
  Session(stock: initStock(), events: @[], rejected: @[])

func submit*(s: Session; cmd: Command): Session {.raises: [].} =
  ## Decides the command; an accepted one appends its events and evolves the stock, a refused
  ## one is recorded in `rejected` and changes nothing else.
  let decided = s.stock.decide(cmd)
  if decided.isOk:
    result = s
    for e in decided.value:
      result.events.add e
      result.stock = result.stock.evolve(e)
  else:
    result = s
    result.rejected.add decided.error

func runAll*(cmds: openArray[Command]): Session {.raises: [].} =
  result = initSession()
  for c in cmds:
    result = result.submit(c)

# ── read side ──────────────────────────────────────────────────────────────

func stockOf*(events: openArray[Event]): Stock {.raises: [].} =
  ## Rebuilds the write-side stock from the events alone.
  result = initStock()
  for e in events:
    result = result.evolve(e)

func continueDashboard*(d: Dashboard; events: openArray[Event]): Dashboard {.raises: [].} =
  ## Folds more events into an existing dashboard.
  result = d
  for e in events:
    case e.kind
    of evReceived:
      result.received += e.qty
    of evShipped:
      result.shipped += e.qty
      result.shipments += 1

func dashboard*(events: openArray[Event]): Dashboard {.raises: [].} =
  ## The dashboard read model, projected from the whole log.
  continueDashboard(Dashboard(), events)
