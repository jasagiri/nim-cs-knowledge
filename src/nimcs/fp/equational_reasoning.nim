## Equational reasoning: refactoring pure code by replacing a form with an equal one
## (ADR-NCK-0002 S1, S6).
##
## In pure code a name can be replaced by its definition and a definition by its name without
## changing the program, so two forms that a short argument shows equal are interchangeable. The
## pairs below are each a staged, readable form and a rewritten form: map/filter/sum fused into
## one pass, an idempotent step removed, a loop replaced by its closed form, a count computed in
## chunks. Each equality is stated as a law and checked on generated inputs; a test is evidence,
## the argument is the proof. The rewrites are valid only for pure functions and exact
## arithmetic: with effects, or with floating point, "equal" forms can differ (`sumLeft`,
## `sumRight`).

import std/[strutils, sequtils]

func stagedTotal*(xs: openArray[int]): int {.raises: [].} =
  ## Sum of `x * 2 + 1` over the even elements, written as separate stages that each build a list.
  let evens = xs.filter(proc(x: int): bool = x mod 2 == 0)
  let doubled = evens.map(proc(x: int): int = x * 2)
  let shifted = doubled.map(proc(x: int): int = x + 1)
  for x in shifted:
    result += x

func fusedTotal*(xs: openArray[int]): int {.raises: [].} =
  ## The same value in one pass: the three stages fused (`map f . map g == map (f . g)`, and
  ## `filter` before `map` becomes a test before the step).
  for x in xs:
    if x mod 2 == 0:
      result += x * 2 + 1

func normalizeStaged*(s: string): string {.raises: [].} =
  ## Strip, lower-case, strip again.
  s.strip.toLowerAscii.strip

func normalizeOnce*(s: string): string {.raises: [].} =
  ## Lower-case, then strip once. Equal to `normalizeStaged`: lower-casing does not change which
  ## characters are whitespace (so it commutes with `strip`), and `strip` is idempotent.
  s.toLowerAscii.strip

func rangeSumLoop*(n: Natural): int {.raises: [].} =
  ## `0 + 1 + ... + n` by a loop. Keep `n` below about 3 * 10^9 so the sum fits in `int`.
  for i in 0 .. n:
    result += i

func rangeSumFormula*(n: Natural): int {.raises: [].} =
  ## The closed form `n * (n + 1) / 2`, equal to `rangeSumLoop(n)` by induction on `n`.
  n * (n + 1) div 2

func countIf*[T](xs: openArray[T]; p: proc(x: T): bool {.noSideEffect, raises: [].}): int {.raises: [].} =
  ## How many elements satisfy `p`.
  for x in xs:
    if p(x):
      inc result

func countIfChunked*[T](xs: openArray[T]; p: proc(x: T): bool {.noSideEffect, raises: [].};
    chunk: Positive): int {.raises: [].} =
  ## The same count computed chunk by chunk and added up. Equal to `countIf` because counting is a
  ## homomorphism from concatenation to addition: `count(a & b) == count(a) + count(b)`.
  var start = 0
  while start < xs.len:
    let stop = min(start + chunk, xs.len)
    result += countIf(xs[start ..< stop], p)
    start = stop

func sumLeft*(xs: openArray[float]): float {.raises: [].} =
  ## Left-to-right sum: `((x0 + x1) + x2) + ...`.
  for x in xs:
    result += x

func sumRight*(xs: openArray[float]): float {.raises: [].} =
  ## Right-to-left sum: `x0 + (x1 + (x2 + ...))`. Not equal to `sumLeft` for floats in general,
  ## because float addition is not associative: reassociating is not an equational step there.
  for i in countdown(xs.high, 0):
    result = xs[i] + result
