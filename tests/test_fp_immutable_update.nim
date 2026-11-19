import std/unittest
import propcheck
import nimcs/fp/[result, immutable_update]

func itemOf(sku: string; qty, price: int): Item {.raises: [].} =
  Item(sku: sku, qty: qty, unitCents: price)

const skus = ["a", "b", "c", "d"]

func items(): Gen[Item] {.raises: [ValueError].} =
  # Any price per item: the same sku may arrive with different prices.
  pair(pick(skus), pair(intIn(1, 5), intIn(1, 100))).map(
    proc(p: (string, (int, int))): Item {.raises: [].} = itemOf(p[0], p[1][0], p[1][1]))

func carts(): Gen[Cart] {.raises: [ValueError].} =
  # Built directly, one line per sku: no update function is needed to make the inputs.
  seqOf(items(), 0, 6).map(proc(xs: seq[Item]): Cart {.raises: [].} =
    result = initCart()
    for it in xs:
      var seen = false
      for have in result.items:
        seen = seen or have.sku == it.sku
      if not seen:
        result.items.add it)

# SPEC: FP-IMMUTABLEUPDATE-01
test "FP-IMMUTABLEUPDATE-01 Given a cart, when an item is added, then the old cart is unchanged":
  let before = initCart().added(itemOf("a", 1, 100)).value
  let snapshot = before
  let after = before.added(itemOf("b", 2, 50)).value
  check before == snapshot
  check before.items.len == 1
  check after.items.len == 2

# SPEC: FP-IMMUTABLEUPDATE-01
test "FP-IMMUTABLEUPDATE-01 Given any cart and item, when added, then the original equals its earlier copy and the total grows by qty times price":
  let outcome = check(pair(carts(), items()), proc(p: (Cart, Item)): bool {.raises: [CatchableError].} =
    let (c, it) = p
    let before = c
    let after = c.added(it)
    if not after.isOk:
      # A refusal must be a price conflict on a sku that is already there.
      return after.error == priceConflict and c == before
    c == before and after.value.totalCents == c.totalCents + it.qty * it.unitCents)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-IMMUTABLEUPDATE-02
test "FP-IMMUTABLEUPDATE-02 Given a chain of updates, when every version is kept, then each one can still be read":
  let v0 = initCart()
  let v1 = v0.added(itemOf("a", 2, 10)).value
  let v2 = v1.added(itemOf("a", 3, 10)).value
  let v3 = v2.removed("a")
  check v0.totalCents == 0
  check v1.totalCents == 20
  check v2.totalCents == 50
  check v3.totalCents == 0
  check v2.items[0].qty == 5

# SPEC: FP-IMMUTABLEUPDATE-03
test "FP-IMMUTABLEUPDATE-03 Given a cart and a sku, when removed twice, then the result equals removing once":
  let outcome = check(pair(carts(), pick(skus)), proc(p: (Cart, string)): bool {.raises: [CatchableError].} =
    p[0].removed(p[1]).removed(p[1]) == p[0].removed(p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-IMMUTABLEUPDATE-03
test "FP-IMMUTABLEUPDATE-03 Given a cart, when the same quantity is set twice, then the result equals setting once":
  let outcome = check(pair(carts(), pair(pick(skus), intIn(1, 9))),
    proc(p: (Cart, (string, int))): bool {.raises: [CatchableError].} =
      let (c, (sku, q)) = p
      let once = c.withQty(sku, q)
      once.isOk and once.value.withQty(sku, q) == once)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-IMMUTABLEUPDATE-04
test "FP-IMMUTABLEUPDATE-04 Given a cart, when the same sku is added twice at one price, then there is one entry with the summed quantity":
  let c = initCart().added(itemOf("a", 2, 10)).value.added(itemOf("a", 3, 10)).value
  check c.items.len == 1
  check c.items[0].qty == 5

# SPEC: FP-IMMUTABLEUPDATE-04
test "FP-IMMUTABLEUPDATE-04 Given any items, when added one after another, then no sku has two entries":
  let outcome = check(seqOf(items(), 0, 10), proc(xs: seq[Item]): bool {.raises: [CatchableError].} =
    var c = initCart()
    for it in xs:
      let r = c.added(it)
      if r.isOk:
        c = r.value
    var seen: seq[string]
    for it in c.items:
      if it.sku in seen:
        return false
      seen.add it.sku
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-IMMUTABLEUPDATE-06
test "FP-IMMUTABLEUPDATE-06 Given a sku in the cart, when added at another price, then priceConflict is reported and the cart is unchanged":
  let c = initCart().added(itemOf("a", 1, 100)).value
  let r = c.added(itemOf("a", 1, 200))
  check r.isErr
  check r.error == priceConflict
  check c.totalCents == 100

# SPEC: FP-IMMUTABLEUPDATE-07
test "FP-IMMUTABLEUPDATE-07 Given a quantity below 1, when added or set, then badQuantity is reported":
  check initCart().added(itemOf("a", 0, 100)).error == badQuantity
  check initCart().added(itemOf("a", -3, 100)).error == badQuantity
  let c = initCart().added(itemOf("a", 1, 100)).value
  check c.withQty("a", 0).error == badQuantity
  check c.withQty("a", low(int)).error == badQuantity

# SPEC: FP-IMMUTABLEUPDATE-05
test "FP-IMMUTABLEUPDATE-05 Given an object, when copied by assignment and the copy is changed, then the original is not":
  var original = initCart().added(itemOf("a", 1, 5)).value
  var copy = original
  copy.items[0].qty = 99
  copy.items.add itemOf("z", 1, 1)
  check original.items.len == 1
  check original.items[0].qty == 1
  original.items[0].qty = 2
  check copy.items[0].qty == 99
