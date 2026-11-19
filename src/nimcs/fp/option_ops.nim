## Working with `std/options` without sentinels (ADR-NCK-0002 S2).
##
## `Option[T]` says "there may be no value". The standard library already gives `map`, `flatMap`,
## `filter`, `get(default)` and `isSome`; this module adds the pieces that are missing when options
## meet each other or meet `Result`: turn absence into a reason (`okOr`), pick the first present
## value (`orElse`), combine two options (`both`), and flip a list of options into an option of a
## list (`sequence`). Reach for it whenever "not found" is an expected answer, not an error.

import std/options
import nimcs/fp/result

func okOr*[T, E](o: Option[T]; reason: E): Result[T, E] {.raises: [].} =
  ## Absence becomes the given error; presence becomes `ok`.
  if o.isSome: Result[T, E](isOk: true, value: o.get)
  else: Result[T, E](isOk: false, error: reason)

func toOption*[T, E](r: Result[T, E]): Option[T] {.raises: [].} =
  ## Forgets why a result failed.
  if r.isOk: some(r.value) else: none(T)

func orElse*[T](a, b: Option[T]): Option[T] {.raises: [].} =
  ## The first option that holds a value (left-biased). `none` is the identity, so this is a
  ## monoid on options.
  if a.isSome: a else: b

func both*[A, B](a: Option[A]; b: Option[B]): Option[(A, B)] {.raises: [].} =
  ## `some` of the pair only when both hold a value.
  if a.isSome and b.isSome: some((a.get, b.get)) else: none((A, B))

func sequence*[T](xs: openArray[Option[T]]): Option[seq[T]] {.raises: [].} =
  ## `some` of all the values, in order, when every element holds one; otherwise `none`.
  var values = newSeqOfCap[T](xs.len)
  for x in xs:
    if x.isNone:
      return none(seq[T])
    values.add x.get
  some(values)

func catSome*[T](xs: openArray[Option[T]]): seq[T] {.raises: [].} =
  ## Keeps the values that are present and drops the absent ones, preserving order.
  result = newSeqOfCap[T](xs.len)
  for x in xs:
    if x.isSome:
      result.add x.get

func firstSome*[T](xs: openArray[Option[T]]): Option[T] {.raises: [].} =
  ## The first element that holds a value, or `none` for an empty or all-absent input.
  for x in xs:
    if x.isSome:
      return x
  none(T)
