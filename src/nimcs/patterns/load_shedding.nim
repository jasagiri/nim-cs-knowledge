## Load shedding: under overload, refuse some work early and say why, instead of slowing everyone.
##
## A service with a queue that grows without bound answers late to every caller. Shedding is the
## decision, taken before the work is queued, to reject a request that cannot succeed: the queue is
## full, only important work is wanted now, or the request's deadline passes before it would be
## served. `decide` is that decision as a pure function of the limits, the time, the current
## queue length and the request, so every rule is a law of a function. The ledger makes it
## idempotent per request id: a client that retries the same id gets the answer it got the first
## time, even if the queue has changed meanwhile, so a retry cannot turn a refusal into a
## double admission or an admission into a surprise. Time and queue length are arguments; the
## caller reads them. Use it at the entry of any queue with callers who can retry or give up;
## pair it with `retry_backoff` on the client side.

import std/tables
import nimcs/fp/result
export result

type
  Priority* = enum
    pLow, pHigh

  Request* = object
    id*: string
    priority*: Priority
    deadline*: int      ## absolute tick by which the answer is useless to the caller

  Reason* = enum
    rNoId, rExpired, rQueueFull, rLowPriorityShed, rDeadlineUnreachable

  Decision* = object
    case admitted*: bool
    of true:
      discard
    of false:
      reason*: Reason

  Limits* = object
    maxQueue: int
    softQueue: int
    ticksPerItem: int

  Ledger* = object
    ## The decisions already given, by request id.
    decided: Table[string, Decision]

func `==`*(a, b: Decision): bool {.raises: [].} =
  if a.admitted != b.admitted: false
  elif a.admitted: true
  else: a.reason == b.reason

func `==`*(a, b: Ledger): bool {.raises: [].} = a.decided == b.decided

func initLimits*(maxQueue, softQueue, ticksPerItem: int): Result[Limits, string] {.raises: [].} =
  ## `softQueue` is the length from which low-priority work is shed; it may not exceed `maxQueue`.
  if ticksPerItem < 1:
    err(Limits, "ticksPerItem must be at least 1")
  elif softQueue < 1 or softQueue > maxQueue:
    err(Limits, "softQueue must be in 1 .. maxQueue")
  else:
    ok(Limits(maxQueue: maxQueue, softQueue: softQueue, ticksPerItem: ticksPerItem), string)

func emptyLedger*(): Ledger {.raises: [].} = Ledger(decided: initTable[string, Decision]())

func admit(): Decision {.raises: [].} = Decision(admitted: true)

func shed(r: Reason): Decision {.raises: [].} = Decision(admitted: false, reason: r)

func judge*(l: Limits; now, queueLen: int; req: Request): Decision {.raises: [].} =
  ## The rules with no memory, checked in this order: an empty id, a deadline already past, a full
  ## queue, a queue at the soft limit for low-priority work, and a deadline that the queue ahead
  ## makes unreachable (the request needs `queueLen + 1` service times).
  if req.id.len == 0: shed(rNoId)
  elif req.deadline <= now: shed(rExpired)
  elif queueLen >= l.maxQueue: shed(rQueueFull)
  elif req.priority == pLow and queueLen >= l.softQueue: shed(rLowPriorityShed)
  elif now + (queueLen + 1) * l.ticksPerItem > req.deadline: shed(rDeadlineUnreachable)
  else: admit()

func decide*(ledger: Ledger; l: Limits; now, queueLen: int;
    req: Request): tuple[ledger: Ledger, decision: Decision] {.raises: [].} =
  ## Idempotent per id: a known id returns its first decision and the same ledger, whatever `now`
  ## and `queueLen` are now. A request with no id is judged but never recorded.
  let fresh = l.judge(now, queueLen, req)
  if req.id.len == 0:
    return (ledger, fresh)
  # A known id answers with its recorded decision; `fresh` is the answer only for an unknown id.
  let d = ledger.decided.getOrDefault(req.id, fresh)
  if ledger.decided.hasKey(req.id):
    return (ledger, d)
  var next = ledger
  next.decided[req.id] = d
  (next, d)

func decidedCount*(ledger: Ledger): int {.raises: [].} = ledger.decided.len

func knows*(ledger: Ledger; id: string): bool {.raises: [].} = ledger.decided.hasKey(id)
