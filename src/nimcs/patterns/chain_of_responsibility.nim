## Chain of Responsibility: a list of "maybe handle it" functions; the first `some` wins.
##
## The OO pattern links handler objects, each holding a reference to its successor and deciding to
## handle or pass on. In Nim a handler is `proc(request): Option[Response]`, a chain is a plain
## `seq` of them, and "pass it on" is simply moving to the next element. `orElse` composes two
## handlers into one, which makes handlers a monoid (associative, with `never` as identity), so
## chains can be nested or built in pieces. Unhandled is a `Result` error, not a nil. Use it for
## approvals, middleware, parsers that try alternatives, and fallbacks. The example approves
## expense claims by the lowest authority whose limit covers the amount.

import std/options
import nimcs/fp/result

type
  Handler*[Req, Resp] = proc(request: Req): Option[Resp] {.noSideEffect, raises: [].}

  Unhandled* = object
    ## No handler in the chain accepted the request.

  Claim* = object
    amount*: int
    category*: string

  Approval* = object
    by*: string
    amount*: int

func `==`*(a, b: Approval): bool {.raises: [].} = a.by == b.by and a.amount == b.amount
func `$`*(a: Approval): string {.raises: [].} = a.by & "@" & $a.amount

func never*[Req, Resp](request: Req): Option[Resp] {.raises: [].} =
  ## The handler that accepts nothing; the identity of `orElse`.
  none(Resp)

func firstSome*[Req, Resp](chain: openArray[Handler[Req, Resp]]; request: Req): Option[Resp] {.raises: [].} =
  ## Asks the handlers in order and returns the first answer. Handlers after the one that answered
  ## are not called.
  for h in chain:
    let r = h(request)
    if r.isSome: return r
  none(Resp)

func handle*[Req, Resp](chain: openArray[Handler[Req, Resp]];
                        request: Req): Result[Resp, Unhandled] {.raises: [].} =
  let r = firstSome(chain, request)
  if r.isSome: ok(r.get, Unhandled) else: err(Resp, Unhandled())

func orElse*[Req, Resp](first, second: Handler[Req, Resp]): Handler[Req, Resp] {.raises: [].} =
  ## One handler that tries `first`, then `second`.
  result = proc(request: Req): Option[Resp] {.noSideEffect, raises: [].} =
    let r = first(request)
    if r.isSome: r else: second(request)

func within*(name: string; limit: int): Handler[Claim, Approval] {.raises: [].} =
  ## Approves claims up to `limit` (inclusive); passes on anything larger or non-positive.
  result = proc(c: Claim): Option[Approval] {.noSideEffect, raises: [].} =
    if c.amount > 0 and c.amount <= limit: some(Approval(by: name, amount: c.amount))
    else: none(Approval)

func onlyCategory*(h: Handler[Claim, Approval]; category: string): Handler[Claim, Approval] {.raises: [].} =
  ## Restricts a handler to one category of claim; other categories are passed on.
  result = proc(c: Claim): Option[Approval] {.noSideEffect, raises: [].} =
    if c.category == category: h(c) else: none(Approval)

func authorityChain*(): seq[Handler[Claim, Approval]] {.raises: [].} =
  ## Clerk up to 100, manager up to 1000, director up to 10000.
  @[within("clerk", 100), within("manager", 1000), within("director", 10000)]
