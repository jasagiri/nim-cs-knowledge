## Type classes in Nim: `concept` constraints on generics, and laws checked per instance
## (ADR-NCK-0002 S3, S6).
##
## A type class says "any type that supports these operations". In Nim that is a generic routine
## whose type parameter is constrained by a `concept`; an instance is simply a type that defines
## the operations (`<` and `==` here). The compiler checks that the operations exist, never that
## they behave: `Orderable` accepts a type whose `<` is not a total order, and `maxOf` then gives
## an arbitrary answer. `isTotalOrderOn` is the missing check; run it on generated values for each
## instance, as the tests do. Use a concept when one routine must serve several unrelated types;
## use a plain generic (`[T]`) when it only moves values around and never inspects them.

import std/options

type
  Orderable* = concept x, y
    ## Types with `<` and `==`: the instance contract of an ordered type.
    (x < y) is bool
    (x == y) is bool

func maxOf*[T: Orderable](xs: openArray[T]): Option[T] {.raises: [].} =
  ## The largest element, or `none` for an empty input.
  if xs.len == 0:
    return none(T)
  var best = xs[0]
  for i in 1 ..< xs.len:
    if best < xs[i]:
      best = xs[i]
  some(best)

func minOf*[T: Orderable](xs: openArray[T]): Option[T] {.raises: [].} =
  ## The smallest element, or `none` for an empty input.
  if xs.len == 0:
    return none(T)
  var best = xs[0]
  for i in 1 ..< xs.len:
    if xs[i] < best:
      best = xs[i]
  some(best)

func insertSorted*[T: Orderable](sortedXs: openArray[T]; x: T): seq[T] {.raises: [].} =
  ## A new sequence with `x` placed after the elements not greater than it; the input, which must
  ## be sorted, is not changed. Inserting into a sorted sequence keeps it sorted.
  result = newSeqOfCap[T](sortedXs.len + 1)
  var placed = false
  for e in sortedXs:
    if not placed and x < e:
      result.add x
      placed = true
    result.add e
  if not placed:
    result.add x

func isSorted*[T: Orderable](xs: openArray[T]): bool {.raises: [].} =
  ## True when no element is smaller than the one before it.
  for i in 1 ..< xs.len:
    if xs[i] < xs[i - 1]:
      return false
  true

func isTotalOrderOn*[T: Orderable](a, b, c: T): bool {.raises: [].} =
  ## The laws of a strict total order on three sample values: irreflexive, asymmetric, transitive,
  ## and total (two values are `==` or one is `<` the other), with `==` agreeing with the order.
  ## It checks only these samples; the caller supplies many.
  let irreflexive = not (a < a)
  let asymmetric = not (a < b and b < a)
  let transitive = not (a < b and b < c) or a < c
  let total = a == b or a < b or b < a
  let consistent = not (a == b) or not (a < b or b < a)
  irreflexive and asymmetric and transitive and total and consistent

func backwards*[T](xs: openArray[T]): seq[T] {.raises: [].} =
  ## The elements in the opposite order. It never looks inside an element, so by parametricity it
  ## commutes with `map`: `xs.map(g).backwards == xs.backwards.map(g)`.
  result = newSeqOfCap[T](xs.len)
  for i in countdown(xs.high, 0):
    result.add xs[i]
