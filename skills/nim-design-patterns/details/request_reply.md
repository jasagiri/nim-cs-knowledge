# Request/reply

## Intent
Ask on top of tell. Actors only send messages, so a question is two messages: a request that carries a correlation id and the asker's reply-to address, and a reply that carries the same id. The requests still waiting are a persistent map (the `Ledger`), each with a context the asker chose and a deadline. Waiting is not a sleep: the host schedules a timeout for the deadline and delivers it as a message. A reply that arrives after the timeout finds nothing pending and is dropped, so every request ends in exactly one of reply or timeout.

## Use when / avoid when
- Use when an actor needs an answer from another actor and must not block or lose track of the question: lookups, RPC over messages, calls to the host's effects.
- Use instead of `observer.md` when one party asks and exactly one answers; use instead of `command.md` when the sender needs the outcome, not just to record the command; use `idempotent_command.md` as well when the request may be redelivered.
- Avoid when the answer can be computed locally: call a function.
- Avoid a timeout that is never delivered by the host: the ledger would keep the request forever. Give every `ask` a deadline and make the host deliver it (or poll `dueAt`).

## Nim shape
The module is `src/nimcs/patterns/request_reply.nim`, built on `actor.nim` (`Address`) and the persistent map `ds/hamt`. `ask(ledger, replyTo, body, context, now, timeout)` returns an `Asked` value: the new ledger, the `Request` to send and the deadline (`now + timeout`, saturating). `replyWith(request, body)` builds the `Reply` with the same id. `onReply` and `onTimeout` return the new ledger and `some(context)` for the event that settled the request, or `none` (ledger unchanged) for a late, duplicate or unknown event. Correlation ids come from the ledger, increase and are never reused. `dueAt(ledger, now)` lists what a polling host should time out.

```nim
import std/options
import nimcs/patterns/actor
import nimcs/patterns/request_reply

let first = initLedger[string]().ask(Address(1), "price of tea?", "tea", 100, 30)
let second = first.ledger.ask(Address(1), "price of rice?", "rice", 100, 10)
doAssert first.deadline == 130 and second.deadline == 110
# The server answers the first request; the second one times out.
let (afterReply, got) = second.ledger.onReply(first.request.replyWith(450))
doAssert got == some("tea")
let (afterTimeout, timedOut) = afterReply.onTimeout(second.request.id)
doAssert timedOut == some("rice")
# A late reply to the second request is dropped, and so is a timeout for the first.
doAssert afterTimeout.onReply(second.request.replyWith(900))[1].isNone
doAssert afterTimeout.onTimeout(first.request.id)[1].isNone
doAssert afterTimeout.pendingCount == 0
```

In an actor, keep the ledger in its state, send `ask`'s request with `sendTo`, and handle `Reply` and timeout messages in `step` by calling `onReply` and `onTimeout`; the returned context says what to do next.

## Laws and invariants
- Whatever mix of replies, timeouts, duplicates and unknown ids arrives, once every leftover request is timed out each request has settled exactly once (PAT-REQREPLY-01).
- A reply or timeout for a request that already ended is dropped and leaves the ledger unchanged (PAT-REQREPLY-02).
- Correlation ids are distinct, increasing and never reused, even after a request is settled (PAT-REQREPLY-03).
- `dueAt` lists exactly the pending requests whose deadline has passed, in id order; deadlines saturate instead of overflowing (PAT-REQREPLY-04).
- `ask` and the settling functions return new ledgers; earlier ones are unchanged (PAT-REQREPLY-05).
- One reply settles only the request with its id (PAT-REQREPLY-06).
- A request carries the id, the reply-to address and the body; the reply carries the same id (PAT-REQREPLY-07).

## Complexity
`ask`, `onReply` and `onTimeout` are O(log32 n) in the number of pending requests; `dueAt` is O(n log n) (it lists the map in key order).

## Pitfalls
Blocking the actor while it waits, with a clock inside:

```nim bad
import std/os

proc ask(server: string; question: string): string =
  send(server, question)
  for _ in 1 .. 50:                   # a sleep is a hidden timeout the test cannot control
    sleep(100)
    if inbox.len > 0: return inbox.pop()
  ""                                  # an empty string hides the timeout from the caller
```

Fix: send the request, keep the context in the ledger, return to the host, and let the reply or the timeout arrive as a message. Give the asker a way to tell a timeout from an answer: they are different messages, and `onTimeout` returns the context, not a fake answer. Never reuse correlation ids (a late reply to an old question would settle a new one).

## Related
- `actor.md` (the messages and the host)
- `supervisor.md` (a server that crashed never replies: the timeout covers it)
- `idempotent_command.md` (a retried request must not repeat its effect)
- `retry_backoff.md` (what to do after a timeout)
- `observer.md`, `command.md` (when no answer is needed)
- `smart_constructor` in nim-functional-core

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `f2b0c2a6b0908171` Making reliable distributed systems in the presence of software errors (Armstrong thesis)
