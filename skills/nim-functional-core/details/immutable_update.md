# Immutable update

## Intent
Instead of changing a value in place, an update takes the old value and returns a new one; the old one stays valid. Every earlier version can still be read, compared or restored, and no other holder of the old value is surprised. Nim makes this cheap and safe: objects and sequences are values, assignment copies, and a `sink` parameter lets the compiler move instead of copy when the caller is done with the old value.

## Use when / avoid when
- Use for domain values (carts, accounts, settings, parsed documents) that several parts of a program read.
- Use when undo, history or "what did it look like before" is wanted.
- Avoid copying very large structures per update: use a persistent structure that shares nodes (see the `ds` area, for example a banker's queue or a persistent map).
- Avoid for a hot inner loop where one local `var` is enough and nobody else sees it.

## Nim shape
`src/nimcs/fp/immutable_update.nim`: a `Cart` of `Item`s whose updates are `func`s returning a new `Cart`.

```nim
import nimcs/fp/[result, immutable_update]

let empty = initCart()
let one = empty.added(Item(sku: "tea", qty: 2, unitCents: 300))
let two = one.flatMap(proc(c: Cart): Result[Cart, CartError] {.noSideEffect, raises: [].} =
  c.added(Item(sku: "tea", qty: 1, unitCents: 300)))
doAssert one.isOk and two.isOk
doAssert empty.totalCents == 0
doAssert one.value.totalCents == 600
doAssert two.value.totalCents == 900
doAssert two.value.removed("tea") == empty
doAssert one.value.added(Item(sku: "tea", qty: 1, unitCents: 999)).error == priceConflict
```

`added(cart: sink Cart; ...)` copies when the caller still uses `cart` afterwards (as above) and moves when it does not. Inside, `var next = cart` takes the value and the body changes only `next`, a local. An update that can be refused returns a `Result`: a quantity below 1 is `badQuantity`, and adding a `sku` already in the cart at a different unit price is `priceConflict`; the cart never guesses which price was meant.

## Laws and invariants
- Adding returns a new cart and leaves the old one unchanged; the total grows by `qty * unitCents` (FP-IMMUTABLEUPDATE-01).
- Every version in a chain of updates keeps its own contents (FP-IMMUTABLEUPDATE-02).
- `removed` and `withQty` are idempotent (FP-IMMUTABLEUPDATE-03).
- A cart has at most one entry per `sku`; adding at the same price sums the quantity (FP-IMMUTABLEUPDATE-04).
- A different price for a `sku` already present is `priceConflict` and the cart is unchanged (FP-IMMUTABLEUPDATE-06); a quantity below 1 is `badQuantity` (FP-IMMUTABLEUPDATE-07).
- Assignment copies: changing the copy never changes the original (FP-IMMUTABLEUPDATE-05).

## Complexity
Each update here copies the item sequence: O(n) time and space for n items, which is fine for small values. Moves (`sink` with a last use) avoid the copy but the update still touches O(n) for `removed`. For large collections use a persistent structure with O(log n) updates.

## Pitfalls
Mutating through a `var` parameter makes every caller's value change behind its back, and the old version is lost.

```nim bad
proc add(cart: var Cart; item: Item) =
  cart.items.add item          # the caller's cart is changed in place
let before = myCart            # `before` is a copy only by luck of the assignment
add(myCart, tea)               # history of this cart is gone
```

```nim
import nimcs/fp/[result, immutable_update]

let before = initCart().added(Item(sku: "tea", qty: 1, unitCents: 300))
let after = before.value.added(Item(sku: "milk", qty: 1, unitCents: 200))
doAssert before.value.items.len == 1      # still true
doAssert after.value.items.len == 2
```

Also keep a `ref` object out of value objects: copying a `ref` field copies the pointer, so "two versions" share one mutable thing.

## Related
`idempotence.md`, `compose.md`, `smart_constructor.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `04c90d5ac6a2d0db` Real World OCaml
