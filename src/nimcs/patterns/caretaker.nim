## Caretaker: revocable forwarding, with the revocation state threaded as data (ADR-NCK-0002).
##
## A caretaker hands out a `Forwarder` (the capability the client holds: it forwards operations to
## the target) and a `Revoker` (the capability the grantor keeps: it cuts the forwarder off).
## Classic caretakers use a mutable cell that every forwarder reads. Here the cell is a value:
## the `Caretaker` holds one slot per forwarder, `forward` takes the caretaker as an argument and
## answers `crRevoked` once the slot is empty, and `revoke` returns a new caretaker whose slot has
## dropped the target. Nothing is hidden or mutable, so every law is checkable as a function of
## values. The price is explicit and deliberate: revocation reaches only the callers that use the
## caretaker value that was revoked. Keep the caretaker in the one place that owns the resource
## (an actor's state, a store threaded through the program), and let clients call through that
## owner (send it a message, or pass the current value). If independent parties must see a
## revocation instantly without going through an owner, a shared mutable cell (a `ref` read by
## all forwarders) is the right tool; it gives up the value semantics and the replayability of
## these laws, so use it only at that edge.
##
## `forward` runs a pure operation (`proc` with `noSideEffect`) on the target; to forward an
## effectful call, return a description of the call as the result and perform it in the shell.
## Every caretaker has a `brand`; its forwarders and revokers carry it, so capabilities of another
## caretaker are refused (`crForeign`) instead of acting on a slot of the same number. Use one
## distinct brand per caretaker.

import std/options
import nimcs/ds/hamt
import nimcs/fp/result

type
  CaretakerError* = enum
    crRevoked, crForeign

  Forwarder* {.requiresInit.} = object
    brand: int
    slot: int

  Revoker* {.requiresInit.} = object
    brand: int
    slot: int

  Caretaker*[T] = object
    brand: int
    next: int
    slots: Hamt[int, Option[T]]   ## `none` once revoked: the target is no longer referenced

  Wrapped*[T] = object
    caretaker*: Caretaker[T]
    forwarder*: Forwarder
    revoker*: Revoker

func initCaretaker*[T](brand: int): Caretaker[T] {.raises: [].} =
  Caretaker[T](brand: brand, next: 0, slots: emptyHamt[int, Option[T]]())

func wrap*[T](c: Caretaker[T]; target: T): Wrapped[T] {.raises: [].} =
  ## A new forwarder to `target` and the revoker for it. Wrapping the same target twice gives two
  ## independent forwarders.
  Wrapped[T](
    caretaker: Caretaker[T](brand: c.brand, next: c.next + 1,
      slots: c.slots.put(c.next, some(target))),
    forwarder: Forwarder(brand: c.brand, slot: c.next),
    revoker: Revoker(brand: c.brand, slot: c.next))

func forward*[T, R](c: Caretaker[T]; f: Forwarder;
    op: proc(t: T): R {.noSideEffect, raises: [].}): Result[R, CaretakerError] {.raises: [].} =
  ## `ok(op(target))` while the forwarder is live; `err(crRevoked)` after revocation; `err(crForeign)`
  ## for a forwarder that belongs to another caretaker.
  if f.brand != c.brand: return err(R, crForeign)
  let slot = c.slots.get(f.slot)
  if slot.isNone: return err(R, crForeign)
  if slot.get.isNone: err(R, crRevoked)
  else: ok(op(slot.get.get), CaretakerError)

func revoke*[T](c: Caretaker[T]; r: Revoker): Result[Caretaker[T], CaretakerError] {.raises: [].} =
  ## Cuts off the forwarder this revoker belongs to. Revoking again changes nothing (it is `ok` of
  ## an equivalent caretaker). A revoker of another caretaker is `err(crForeign)`: it is refused,
  ## not ignored.
  if r.brand != c.brand or not c.slots.contains(r.slot): err(Caretaker[T], crForeign)
  else:
    ok(Caretaker[T](brand: c.brand, next: c.next, slots: c.slots.put(r.slot, none(T))),
      CaretakerError)

func isRevoked*[T](c: Caretaker[T]; f: Forwarder): bool {.raises: [].} =
  ## True when `f` is one of this caretaker's forwarders and has been revoked.
  if f.brand != c.brand: return false
  let slot = c.slots.get(f.slot)
  slot.isSome and slot.get.isNone

func liveCount*[T](c: Caretaker[T]): int {.raises: [].} =
  ## The forwarders that still reach their target.
  for (_, slot) in c.slots.toSortedSeq:
    if slot.isSome: inc result
