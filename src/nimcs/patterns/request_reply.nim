## Request/reply: ask on top of tell, with correlation ids and a timeout that is a message
## (ADR-NCK-0002).
##
## Actors only tell. To ask, the requester sends a `Request` carrying a correlation id and its own
## reply-to address, and remembers the request in a `Ledger`: a persistent map from the id to a
## context the requester chose (what to do with the answer) and a deadline. The answer comes back
## as a `Reply` with the same id. Waiting is not a sleep: the host schedules a timeout for the
## deadline that `ask` returns and delivers it as a message, and the requester calls `onTimeout`.
## Both `onReply` and `onTimeout` return the context only for the first event that settles a
## request; the second one (a late reply after a timeout, a duplicate reply, an unknown id) finds
## nothing pending and is dropped. So every request ends in exactly one of reply or timeout.
## Time is data (`now`, `timeout` are ticks the host passes in); there is no clock here.

import std/options
import nimcs/ds/hamt
import nimcs/patterns/actor

type
  CorrelationId* = distinct int
    ## Allocated by the ledger, increasing, never reused.

  Request*[Q] = object
    id*: CorrelationId
    replyTo*: Address
    body*: Q

  Reply*[A] = object
    id*: CorrelationId
    body*: A

  Entry[C] = object
    context: C
    deadline: int

  Ledger*[C] = object
    ## The requests still waiting for an answer.
    next: int
    waiting: Hamt[int, Entry[C]]

  Asked*[C, Q] = object
    ledger*: Ledger[C]
    request*: Request[Q]     ## to send to the server
    deadline*: int           ## when the host should deliver the timeout

func `==`*(a, b: CorrelationId): bool {.borrow.}
func `$`*(a: CorrelationId): string {.borrow.}

func initLedger*[C](): Ledger[C] {.raises: [].} =
  Ledger[C](next: 0, waiting: emptyHamt[int, Entry[C]]())

func pendingCount*[C](l: Ledger[C]): int {.raises: [].} = l.waiting.len

func isPending*[C](l: Ledger[C]; id: CorrelationId): bool {.raises: [].} =
  l.waiting.contains(int(id))

func addSaturating(a, b: int): int =
  if b > 0 and a > high(int) - b: high(int)
  elif b < 0 and a < low(int) - b: low(int)
  else: a + b

func ask*[Q, C](l: Ledger[C]; replyTo: Address; body: Q; context: C; now, timeout: int):
    Asked[C, Q] {.raises: [].} =
  ## Makes a request and remembers `context` until it is settled. The deadline is `now + timeout`
  ## (saturating); a timeout of 0 or less is due at once.
  let deadline = addSaturating(now, timeout)
  Asked[C, Q](
    ledger: Ledger[C](next: l.next + 1,
      waiting: l.waiting.put(l.next, Entry[C](context: context, deadline: deadline))),
    request: Request[Q](id: CorrelationId(l.next), replyTo: replyTo, body: body),
    deadline: deadline)

func replyWith*[Q, A](req: Request[Q]; body: A): Reply[A] {.raises: [].} =
  ## What the server sends to `req.replyTo`.
  Reply[A](id: req.id, body: body)

func settle[C](l: Ledger[C]; id: CorrelationId): (Ledger[C], Option[C]) =
  let e = l.waiting.get(int(id))
  if e.isNone: (l, none(C))
  else: (Ledger[C](next: l.next, waiting: l.waiting.remove(int(id))), some(e.get.context))

func onReply*[A, C](l: Ledger[C]; reply: Reply[A]): (Ledger[C], Option[C]) {.raises: [].} =
  ## `some(context)` if this reply settled a pending request; `none` (ledger unchanged) if the
  ## request already ended or never existed.
  l.settle(reply.id)

func onTimeout*[C](l: Ledger[C]; id: CorrelationId): (Ledger[C], Option[C]) {.raises: [].} =
  ## `some(context)` if the request was still pending; `none` (ledger unchanged) if a reply won.
  l.settle(id)

func dueAt*[C](l: Ledger[C]; now: int): seq[CorrelationId] {.raises: [].} =
  ## The pending requests whose deadline is `now` or earlier, in id order. For a host that polls
  ## instead of scheduling one timer per request.
  for (k, e) in l.waiting.toSortedSeq:
    if e.deadline <= now: result.add CorrelationId(k)
