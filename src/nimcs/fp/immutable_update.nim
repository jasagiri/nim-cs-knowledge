## Copy-and-update of value objects (ADR-NCK-0002 S3, S4).
##
## A `Cart` is a plain value: "changing" it means building a new `Cart` and leaving the old one
## valid, so every earlier version can still be read, compared or restored. Nim copies objects and
## sequences on assignment, which is what makes this safe; a `sink` parameter lets the compiler move
## the argument instead of copying it when the caller no longer needs it. The module is a worked
## example of the pattern: each update is a `func` that takes the old value and returns the new one.

import nimcs/fp/result

type
  CartError* = enum
    badQuantity, priceConflict

  Item* = object
    sku*: string
    qty*: int
    unitCents*: int

  Cart* = object
    ## Items in the order they were first added; at most one entry per `sku`.
    items*: seq[Item]

func initCart*(): Cart {.raises: [].} =
  Cart(items: @[])

func indexOf(items: seq[Item]; sku: string): int {.raises: [].} =
  result = -1
  for i, it in items:
    if it.sku == sku:
      return i

func added*(cart: sink Cart; item: Item): Result[Cart, CartError] {.raises: [].} =
  ## A cart with `item` added; the quantity is summed when the `sku` is already there.
  ## `item.qty` must be at least 1 (`badQuantity`), and an item whose `sku` is already in the
  ## cart must carry the same unit price (`priceConflict`): the cart never guesses which price is meant.
  ## `cart` is `sink`: a caller who keeps using the old cart gets a copy, one who does not gets a move.
  if item.qty < 1:
    return err(Cart, badQuantity)
  var next = cart
  let at = indexOf(next.items, item.sku)
  if at < 0:
    next.items.add item
  elif next.items[at].unitCents != item.unitCents:
    return err(Cart, priceConflict)
  else:
    next.items[at].qty += item.qty
  ok(next, CartError)

func withQty*(cart: sink Cart; sku: string; qty: int): Result[Cart, CartError] {.raises: [].} =
  ## A cart where `sku` has exactly `qty` units (`qty` at least 1, else `badQuantity`); a `sku`
  ## that is not in the cart is left alone. Setting the same quantity twice is the same as
  ## setting it once.
  if qty < 1:
    return err(Cart, badQuantity)
  var next = cart
  let at = indexOf(next.items, sku)
  if at >= 0:
    next.items[at].qty = qty
  ok(next, CartError)

func removed*(cart: sink Cart; sku: string): Cart {.raises: [].} =
  ## A cart without `sku`. Removing an absent `sku` changes nothing, so removing twice equals once.
  result = Cart(items: @[])
  for it in cart.items:
    if it.sku != sku:
      result.items.add it

func totalCents*(cart: Cart): int {.raises: [].} =
  ## Sum of `qty * unitCents` over the items. Precondition: the sum fits in an `int`.
  for it in cart.items:
    result += it.qty * it.unitCents

func `==`*(a, b: Cart): bool {.raises: [].} =
  a.items == b.items
