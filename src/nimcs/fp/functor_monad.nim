## Functor, applicative and monad shapes across Nim's container types (ADR-NCK-0002 S2, S6).
##
## `Option[T]` (std/options), `Result[T, E]` (nimcs/fp/result), `seq[T]` and `Stream[T]`
## (nimcs/fp/lazy_stream) each have their own `map`; the first three also have a `flatMap`. They
## share a shape, not a type: Nim 2 cannot write "any container `F` with `map`" as a type
## parameter, so the shape is a convention that the laws in the tests pin down. This module adds
## what is missing for that shape to be complete: `ap` (apply a wrapped function to a wrapped
## value), `map2` (combine two wrapped values), and `flatMap` for `seq` (the list monad).
## Use it to combine independent wrapped values; use `flatMap` when a later step depends on an
## earlier result.

import std/options
import nimcs/fp/[result, compose]

func ap*[A, B](f: Option[Fn[A, B]]; x: Option[A]): Option[B] {.raises: [].} =
  ## `some` of the application when both hold a value, else `none`.
  if f.isSome and x.isSome: some(f.get()(x.get())) else: none(B)

func ap*[A, B, E](f: Result[Fn[A, B], E]; x: Result[A, E]): Result[B, E] {.raises: [].} =
  ## Applies the function when both are `ok`. When both failed, the error of `f` is reported
  ## (left to right); no error is collected from `x` then.
  if not f.isOk: Result[B, E](isOk: false, error: f.error)
  elif not x.isOk: Result[B, E](isOk: false, error: x.error)
  else: Result[B, E](isOk: true, value: f.value(x.value))

func ap*[A, B](fs: openArray[Fn[A, B]]; xs: openArray[A]): seq[B] {.raises: [].} =
  ## Every function applied to every value, functions in the outer loop.
  result = newSeqOfCap[B](fs.len * xs.len)
  for f in fs:
    for x in xs:
      result.add f(x)

func flatMap*[A, B](xs: openArray[A]; f: proc(x: A): seq[B] {.noSideEffect, raises: [].}): seq[B] {.raises: [].} =
  ## Maps every element to a list and concatenates the lists in order (the list monad).
  for x in xs:
    result.add f(x)

func map2*[A, B, C](a: Option[A]; b: Option[B];
    f: proc(x: A; y: B): C {.noSideEffect, raises: [].}): Option[C] {.raises: [].} =
  ## Combines two independent options; `none` if either is `none`.
  if a.isSome and b.isSome: some(f(a.get(), b.get())) else: none(C)

func map2*[A, B, C, E](a: Result[A, E]; b: Result[B, E];
    f: proc(x: A; y: B): C {.noSideEffect, raises: [].}): Result[C, E] {.raises: [].} =
  ## Combines two independent results; the first error (left to right) wins.
  if not a.isOk: Result[C, E](isOk: false, error: a.error)
  elif not b.isOk: Result[C, E](isOk: false, error: b.error)
  else: Result[C, E](isOk: true, value: f(a.value, b.value))
