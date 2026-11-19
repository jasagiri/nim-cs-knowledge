## Monoids: a way to combine two values, and a value that changes nothing (ADR-NCK-0002 S3, S6).
##
## A `Monoid[T]` bundles `empty` and `combine` and is only a monoid if two laws hold:
## `combine(empty, x) == x == combine(x, empty)` (identity) and
## `combine(combine(a, b), c) == combine(a, combine(b, c))` (associativity). Associativity is what
## lets `mconcat` fold a sequence in any grouping, for example in halves on two threads, and
## identity is what gives an empty input a sensible answer. `Monoid` values are built by the
## constructors below; the laws are checked by the tests, not by the type.
##
## Integer `sum` and `product` assume no overflow: with overflow they are not even defined, so they
## are not a monoid on all of `int`.

import std/tables

type
  Monoid*[T] = object
    empty*: T
    combine*: proc(a, b: T): T {.noSideEffect, raises: [].}

func sumMonoid*(): Monoid[int] {.raises: [].} =
  Monoid[int](empty: 0, combine: proc(a, b: int): int {.noSideEffect, raises: [].} = a + b)

func productMonoid*(): Monoid[int] {.raises: [].} =
  Monoid[int](empty: 1, combine: proc(a, b: int): int {.noSideEffect, raises: [].} = a * b)

func maxMonoid*(): Monoid[int] {.raises: [].} =
  ## The identity is `low(int)`: the maximum of nothing is the smallest `int`.
  Monoid[int](empty: low(int), combine: proc(a, b: int): int {.noSideEffect, raises: [].} = max(a, b))

func minMonoid*(): Monoid[int] {.raises: [].} =
  ## The identity is `high(int)`.
  Monoid[int](empty: high(int), combine: proc(a, b: int): int {.noSideEffect, raises: [].} = min(a, b))

func stringMonoid*(): Monoid[string] {.raises: [].} =
  ## Concatenation: associative but not commutative.
  Monoid[string](empty: "", combine: proc(a, b: string): string {.noSideEffect, raises: [].} = a & b)

func seqMonoid*[T](): Monoid[seq[T]] {.raises: [].} =
  Monoid[seq[T]](empty: @[], combine: proc(a, b: seq[T]): seq[T] {.noSideEffect, raises: [].} = a & b)

func mapMonoid*[K, V](values: Monoid[V]): Monoid[Table[K, V]] {.raises: [].} =
  ## Merges tables; a key present in both gets `values.combine(left, right)`. The result is a
  ## monoid whenever `values` is, and is commutative exactly when `values.combine` is.
  Monoid[Table[K, V]](
    empty: initTable[K, V](),
    combine: proc(a, b: Table[K, V]): Table[K, V] {.noSideEffect, raises: [].} =
      result = a
      for k, v in b:
        # An absent key counts as `values.empty`, which changes nothing when combined.
        result[k] = values.combine(result.getOrDefault(k, values.empty), v))

func mconcat*[T](m: Monoid[T]; xs: openArray[T]): T {.raises: [].} =
  ## Combines all the elements, left to right; an empty input gives `m.empty`.
  result = m.empty
  for x in xs:
    result = m.combine(result, x)

func foldMap*[A, T](m: Monoid[T]; xs: openArray[A];
    f: proc(x: A): T {.noSideEffect, raises: [].}): T {.raises: [].} =
  ## Maps every element into the monoid and combines the results, without building the mapped list.
  result = m.empty
  for x in xs:
    result = m.combine(result, f(x))
