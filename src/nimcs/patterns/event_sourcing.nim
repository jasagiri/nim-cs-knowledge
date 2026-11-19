## Event sourcing: the state of an entity is a fold over the facts that happened to it.
##
## Instead of storing the current balance, store the list of events (deposited, withdrawn) and
## compute the balance by folding `apply` over them. The log is the source of truth and is only
## ever appended to; any past state can be rebuilt, and a snapshot is nothing but a saved
## intermediate value of the same fold. Use it when the history matters (audit, undo, temporal
## queries) or when several read models must be derived from the same facts (see `cqrs`).

type
  EventKind* = enum
    evDeposited, evWithdrawn

  Event* = object
    ## A fact in the past tense. `amount` is positive; the direction is in `kind`.
    kind*: EventKind
    amount*: int

  Account* = object
    ## The folded state. `version` counts the events folded in.
    balance*: int
    version*: int

func deposited*(amount: Positive): Event {.raises: [].} =
  Event(kind: evDeposited, amount: amount)

func withdrawn*(amount: Positive): Event {.raises: [].} =
  Event(kind: evWithdrawn, amount: amount)

func initAccount*(): Account {.raises: [].} =
  ## The state before any event: the fold's starting value.
  Account(balance: 0, version: 0)

func apply*(a: Account; e: Event): Account {.raises: [].} =
  ## One step of the fold. Total: events are facts, so it never refuses one (a command that
  ## would overdraw is refused before an event exists, see `cqrs`).
  let delta =
    case e.kind
    of evDeposited: e.amount
    of evWithdrawn: -e.amount
  Account(balance: a.balance + delta, version: a.version + 1)

func replayFrom*(snapshot: Account; tail: openArray[Event]): Account {.raises: [].} =
  ## Continues the fold from a saved state.
  result = snapshot
  for e in tail:
    result = result.apply(e)

func replay*(events: openArray[Event]): Account {.raises: [].} =
  ## The whole fold from the empty account.
  initAccount().replayFrom(events)

func snapshotAt*(events: openArray[Event]; upTo: int): Account {.raises: [].} =
  ## The state after the first `upTo` events; a count below 0 or beyond the log is clamped.
  let n = max(0, min(upTo, events.len))
  replay(events.toOpenArray(0, n - 1))

func appended*(log: seq[Event]; e: Event): seq[Event] {.raises: [].} =
  ## A new log with `e` at the end; `log` itself is untouched.
  result = log
  result.add e
