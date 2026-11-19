## Sealer/unsealer: a matched pair of capabilities over a sealed box (ADR-NCK-0002).
##
## `newPair` makes a `Sealer` and an `Unsealer` with the same brand. `seal` puts any value in a
## `Box`; `unseal` opens a box only when the unsealer's brand is the box's brand, otherwise it
## answers `seWrongBrand`. A box can be passed around, stored and compared by identity of
## position, but only the holder of the matching unsealer can read it, and whoever holds only the
## sealer can seal values but not read them back. This is how a party hands out an opaque token
## (a ticket, a session, a permission) that others can carry but not forge or open, and how rights
## amplification works: a value's real authority sits inside a box that only the owner's
## unsealer can open.
##
## All three types are sealed (private fields, `{.requiresInit.}`), so outside this module a
## brand cannot be written down, copied from a box or guessed into a value. Brands are not random:
## they come from a `Mint` that the program threads through the pair creations (no hidden
## counter, no global). Two pairs from one mint never match, and that is the only case in which
## the law "a pair's unsealer opens only its own boxes" holds: two mints started from the same
## seed repeat the same brands, and their pairs then open each other's boxes. Create one mint at
## the program's start and pass it on.

import nimcs/fp/result

type
  Mint* = object
    ## Hands out distinct brands. It is a value: `newPair` returns the next one.
    next: int

  Sealer* {.requiresInit.} = object
    brand: int

  Unsealer* {.requiresInit.} = object
    brand: int

  Box*[T] {.requiresInit.} = object
    brand: int
    content: T

  SealError* = enum
    seWrongBrand

func initMint*(seed: int): Mint {.raises: [].} = Mint(next: seed)

func newPair*(m: Mint): (Mint, Sealer, Unsealer) {.raises: [].} =
  ## A fresh pair and the mint to use for the next one.
  (Mint(next: m.next + 1), Sealer(brand: m.next), Unsealer(brand: m.next))

func seal*[T](s: Sealer; value: T): Box[T] {.raises: [].} =
  Box[T](brand: s.brand, content: value)

func unseal*[T](u: Unsealer; box: Box[T]): Result[T, SealError] {.raises: [].} =
  ## The sealed value if the brands match, `err(seWrongBrand)` otherwise.
  if u.brand == box.brand: ok(box.content, SealError)
  else: err(T, seWrongBrand)
