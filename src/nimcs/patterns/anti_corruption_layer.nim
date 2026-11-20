## Anti-corruption layer: translate a foreign model at the border so it never leaks inward.
##
## Another system's model (a supplier's order message) has its own words, codes and number formats,
## and it changes when they decide. If its types reach into your code, every change of theirs is a
## change of yours, and its mistakes (a status code you never meant to support) become your states.
## The layer is the only place that knows both. It is a pair of functions per foreign version: one
## from the foreign record to your `Order`, built through the same smart constructor as every
## order of your own, and one back; your code takes `Order` and cannot be handed a foreign record
## (the compiler refuses it). A new foreign version is a new pair, and nothing inward moves.
## Refusals are values with a reason and a position, not zeros and defaults. Use it where a model
## you do not control meets one you do; do not use it between two parts of your own model.

import nimcs/fp/result
export result

type
  OrderStatus* = enum
    osActive, osShipped, osCancelled

  Cents* = distinct int

  Order* = object
    ## The inner model: a non-empty id and a total that is never negative.
    id*: string
    status*: OrderStatus
    total*: Cents

  TranslateError* = enum
    teEmptyId, teUnknownStatus, teBadAmount

  ForeignOrderV1* = object
    ## The supplier's first format: a status letter and a decimal amount as text, "12.50".
    reference*: string
    statusCode*: string
    amount*: string

  ForeignOrderV2* = object
    ## Their second format: status words and an integer number of cents.
    orderId*: string
    state*: string
    minorUnits*: int

  Refusal* = tuple[index: int, error: TranslateError]

  Translated* = tuple[orders: seq[Order], refused: seq[Refusal]]

func `==`*(a, b: Cents): bool {.borrow.}
func `<`*(a, b: Cents): bool {.borrow.}
func `$`*(c: Cents): string {.borrow.}

func initOrder*(id: string; status: OrderStatus; total: int): Result[Order, TranslateError] {.raises: [].} =
  ## The one place the inner invariants are checked; every translator goes through it.
  if id.len == 0:
    err(Order, teEmptyId)
  elif total < 0:
    err(Order, teBadAmount)
  else:
    ok(Order(id: id, status: status, total: Cents(total)), TranslateError)

func canShip*(o: Order): bool {.raises: [].} =
  ## Inner business rule. It names only inner types, so a foreign record cannot reach it.
  o.status == osActive and int(o.total) > 0

func parseAmountV1(s: string): Result[int, TranslateError] {.raises: [].} =
  ## "digits.dd" with 1 to 9 whole digits (the length is checked first, so no overflow).
  let dot = s.len - 3
  if dot < 1 or dot > 9 or s[dot] != '.':
    return err(int, teBadAmount)
  var cents = 0
  for i, c in s:
    if i != dot:
      if c notin {'0' .. '9'}:
        return err(int, teBadAmount)
      cents = cents * 10 + (ord(c) - ord('0'))
  ok(cents, TranslateError)

func statusV1(code: string): Result[OrderStatus, TranslateError] {.raises: [].} =
  case code
  of "A": ok(osActive, TranslateError)
  of "S": ok(osShipped, TranslateError)
  of "X": ok(osCancelled, TranslateError)
  else: err(OrderStatus, teUnknownStatus)

func statusV2(word: string): Result[OrderStatus, TranslateError] {.raises: [].} =
  case word
  of "ACTIVE": ok(osActive, TranslateError)
  of "SHIPPED": ok(osShipped, TranslateError)
  of "CANCELLED": ok(osCancelled, TranslateError)
  else: err(OrderStatus, teUnknownStatus)

func fromV1*(f: ForeignOrderV1): Result[Order, TranslateError] {.raises: [].} =
  ## Checks in a fixed order: id, status, amount; the first problem is the error.
  if f.reference.len == 0:
    return err(Order, teEmptyId)
  let status = statusV1(f.statusCode)
  if status.isErr:
    return err(Order, status.error)
  let amount = parseAmountV1(f.amount)
  if amount.isErr:
    return err(Order, amount.error)
  initOrder(f.reference, status.value, amount.value)

func fromV2*(f: ForeignOrderV2): Result[Order, TranslateError] {.raises: [].} =
  if f.orderId.len == 0:
    return err(Order, teEmptyId)
  let status = statusV2(f.state)
  if status.isErr:
    return err(Order, status.error)
  initOrder(f.orderId, status.value, f.minorUnits)

func toV1*(o: Order): ForeignOrderV1 {.raises: [].} =
  let cents = int(o.total)
  let frac = cents mod 100
  let code = case o.status
    of osActive: "A"
    of osShipped: "S"
    of osCancelled: "X"
  ForeignOrderV1(reference: o.id, statusCode: code,
    amount: $(cents div 100) & "." & $(frac div 10) & $(frac mod 10))

func toV2*(o: Order): ForeignOrderV2 {.raises: [].} =
  let word = case o.status
    of osActive: "ACTIVE"
    of osShipped: "SHIPPED"
    of osCancelled: "CANCELLED"
  ForeignOrderV2(orderId: o.id, state: word, minorUnits: int(o.total))

func translateAll*[F](xs: seq[F]; translate: proc(f: F): Result[Order, TranslateError] {.noSideEffect, raises: [].}
    ): Translated {.raises: [].} =
  ## A bad record does not stop the batch and is not dropped silently: it is listed with its index.
  result = (orders: @[], refused: @[])
  for i, x in xs:
    let r = translate(x)
    if r.isOk:
      result.orders.add r.value
    else:
      result.refused.add (index: i, error: r.error)
