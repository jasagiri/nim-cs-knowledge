## Dependency record: dependencies are an object of procs, and a test double is another object.
##
## Business logic that needs the clock and a mail sender takes a `Deps` value instead of calling
## them. The production record holds the real procs; a test builds a record from a fixed clock
## and a sender that writes into a list. No interface type, no framework, no global to reset.
## `withClock` and `withSender` replace one field and keep the rest, so a test changes only the
## dependency it cares about. Use it for the few effects a unit needs. When the sequence of
## effects itself must be inspected or optimised, make the program data instead
## (`free_interpreter`).

import nimcs/fp/result

type
  Clock* = proc(): int {.raises: [].}
    ## Today as a day number.

  Sender* = proc(to, body: string): Result[int, string] {.raises: [].}
    ## Sends one message; the `int` is the message id, the error says why it failed.

  Deps* = object
    now*: Clock
    send*: Sender

  RemindError* = object
    ## Why a run stopped, and what had already gone out before it did.
    reason*: string
    sentIds*: seq[int]

  Invoice* = object
    id*: int
    customer*: string
    dueDay*: int
    paid*: bool

func withClock*(deps: Deps; now: Clock): Deps {.raises: [].} =
  ## The same dependencies with another clock.
  Deps(now: now, send: deps.send)

func withSender*(deps: Deps; send: Sender): Deps {.raises: [].} =
  ## The same dependencies with another sender.
  Deps(now: deps.now, send: send)

proc remindOverdue*(deps: Deps; invoices: openArray[Invoice]): Result[seq[int], RemindError] {.raises: [].} =
  ## Sends one reminder per unpaid invoice that is due before today, in list order, and returns
  ## the message ids. It is a `proc`, not a `func`, because the record it is given may perform
  ## effects. The first send that fails stops the run; the error carries the sender's reason and the ids
  ## of the messages already sent, which cannot be taken back.
  let today = deps.now()
  var ids: seq[int]
  for inv in invoices:
    if not inv.paid and inv.dueDay < today:
      let sent = deps.send(inv.customer, "Invoice " & $inv.id & " was due on day " & $inv.dueDay)
      if sent.isErr:
        return err(seq[int], RemindError(reason: sent.error, sentIds: ids))
      ids.add sent.value
  ok(ids, RemindError)
