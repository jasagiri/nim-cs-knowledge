## Strategy: the algorithm you swap is a function value.
##
## The OO pattern puts each interchangeable algorithm in its own class behind one interface so the
## caller can choose at run time. In Nim the interface is a proc type, the classes are procs (or
## closures made by a constructor func), and "choosing" is passing an argument. Here the varying
## part is how an order total is discounted; `checkout` never learns which rule it received. Use it
## when one step of a computation has several interchangeable implementations. When the choice is
## fixed at compile time, the proc can be passed as a generic parameter instead (`total2` below);
## that removes the closure but is not a promise of inlining.
##
## Prices are `Cents >= 0` (see `cents`); amounts near `high(int)` are handled without overflow.

import std/options

type
  Cents* = distinct int

  PriceRule* = proc(price: Cents): Cents {.noSideEffect, raises: [].}
    ## A strategy: maps a price to a price. The constructors below keep results in `0 .. price`.

func `==`*(a, b: Cents): bool {.borrow.}
func `<=`*(a, b: Cents): bool {.borrow.}
func `<`*(a, b: Cents): bool {.borrow.}
func `$`*(a: Cents): string {.borrow.}

func cents*(n: int): Option[Cents] {.raises: [].} =
  ## Smart constructor: a price is never negative.
  if n < 0: none(Cents) else: some(Cents(n))

func value*(c: Cents): int {.raises: [].} = int(c)

func noDiscount*(price: Cents): Cents {.raises: [].} =
  ## The identity strategy.
  price

func percentOff*(pct: int): PriceRule {.raises: [].} =
  ## Takes `pct` percent off, rounding the discount down. `pct` is clamped into 0..100.
  ## The discount is computed as `q*p + (r*p) div 100` for `price = 100*q + r`, which equals
  ## `(price*p) div 100` for non-negative prices without ever forming `price*p` (no overflow).
  let p = max(0, min(100, pct))
  result = proc(price: Cents): Cents {.noSideEffect, raises: [].} =
    let v = value(price)
    Cents(v - ((v div 100) * p + ((v mod 100) * p) div 100))

func flatOff*(amount: int): PriceRule {.raises: [].} =
  ## Takes a fixed amount off, never going below zero. A negative amount counts as zero.
  let a = max(0, amount)
  result = proc(price: Cents): Cents {.noSideEffect, raises: [].} =
    if value(price) <= a: Cents(0) else: Cents(value(price) - a)

func then*(first, second: PriceRule): PriceRule {.raises: [].} =
  ## Applies `first`, then `second` to its result.
  result = proc(price: Cents): Cents {.noSideEffect, raises: [].} =
    second(first(price))

func sumSaturating(items: openArray[Cents]): Cents {.raises: [].} =
  ## Sum of the items; a total beyond `high(int)` stays at `high(int)` instead of overflowing.
  var sum = 0
  for it in items:
    let x = value(it)
    sum = if x > 0 and sum > high(int) - x: high(int) else: sum + x
  Cents(sum)

func checkout*(items: openArray[Cents]; rule: PriceRule): Cents {.raises: [].} =
  ## The context: sums the items (saturating at `high(int)`), then lets the strategy decide the
  ## final price. Items are assumed non-negative (build them with `cents`).
  rule(sumSaturating(items))

func total2*[R](items: openArray[Cents]; rule: R): Cents {.raises: [].} =
  ## Same, with the strategy as a generic parameter: the rule's type is known at compile time, so
  ## no closure is required (whether the C compiler inlines the call is not guaranteed; measure).
  rule(sumSaturating(items))

func cheapest*(rules: openArray[PriceRule]; price: Cents): Cents {.raises: [].} =
  ## Best price over all strategies (no rules: the price itself).
  result = price
  for r in rules:
    let p = r(price)
    if p < result: result = p
