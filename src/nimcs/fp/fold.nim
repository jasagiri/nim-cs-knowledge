## Folds: one loop that builds any result from a sequence (ADR-NCK-0002 S3, S5).
##
## `foldLeft` consumes from the left, `foldRight` from the right, `scan` keeps every intermediate
## accumulator, and `unfold` is the dual: it grows a sequence from a seed. Sum, length, map, filter,
## reverse and "rebuild the list" are all folds with a different step function, so a fold is the
## loop to write first when a result is built by visiting each element once. The accumulator is a
## local `var` inside each routine; callers only see values going in and out. The names differ
## from `std/sequtils.foldl` and `foldr` on purpose, so both modules can be imported together.

import std/options

func foldLeft*[T, A](xs: openArray[T]; init: A;
    f: proc(acc: A; x: T): A {.noSideEffect, raises: [].}): A {.raises: [].} =
  ## `f(...f(f(init, xs[0]), xs[1])..., xs[^1])`. An empty input gives `init`.
  var acc = init
  for x in xs:
    acc = f(acc, x)
  acc

func foldRight*[T, A](xs: openArray[T]; init: A;
    f: proc(x: T; acc: A): A {.noSideEffect, raises: [].}): A {.raises: [].} =
  ## `f(xs[0], f(xs[1], ... f(xs[^1], init)))`. The step sees the element first, the accumulator second.
  var acc = init
  for i in countdown(xs.high, 0):
    acc = f(xs[i], acc)
  acc

func scan*[T, A](xs: openArray[T]; init: A;
    f: proc(acc: A; x: T): A {.noSideEffect, raises: [].}): seq[A] {.raises: [].} =
  ## All the accumulators of `foldLeft`, starting with `init`: the result has `xs.len + 1` elements.
  result = newSeqOfCap[A](xs.len + 1)
  var acc = init
  result.add acc
  for x in xs:
    acc = f(acc, x)
    result.add acc

func unfold*[S, T](seed: S;
    step: proc(s: S): Option[(T, S)] {.noSideEffect, raises: [].};
    limit: Natural): seq[T] {.raises: [].} =
  ## Grows a sequence: `step` returns the next element and the next state, or `none` to stop.
  ## At most `limit` elements are produced, so a step that never stops cannot loop forever.
  var state = seed
  while result.len < limit:
    let next = step(state)
    if next.isNone:
      break
    result.add next.get[0]
    state = next.get[1]
