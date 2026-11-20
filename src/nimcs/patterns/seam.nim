## Seam: a place where behaviour can be changed without editing the code at that place.
##
## Legacy code reaches for what it needs (a price list, a clock, a database) from inside, so it
## cannot be run, or tested, without all of it. A seam is a point where the call can be redirected:
## in functional Nim the simplest is a parameter, a proc the routine is handed (a *function seam*;
## a record of procs is the same idea for several operations). Making a seam must not change what the
## routine does, so the first test is old against new on the same inputs. With the seam in place a
## test supplies its own answers, and a pinned list of input and output pairs (a characterization)
## says whether a later change kept the behaviour nobody wrote down. Here a hard-wired price list
## becomes a seam. The old routine counted an unknown SKU as 0; the seam version says so instead
## of inventing a price, which is the one difference, shown by its own law. Use it before changing code
## you cannot yet test, and keep the default seam equal to the old wiring until the pins are green.

import std/options
import nimcs/fp/result
export result

type
  Seam* = proc(sku: string): Option[int] {.noSideEffect, raises: [].}
    ## Answers the price of a SKU in cents, or none when it does not know the SKU.

  PriceError* = object
    unknownSku*: string

  Total* = proc(skus: seq[string]): int {.noSideEffect, raises: [].}

  Pin* = tuple[input: seq[string], output: int]

  Pins* = seq[Pin]

func hardWiredPrice(sku: string): int {.raises: [].} =
  case sku
  of "apple": 120
  of "pear": 150
  of "fig": 300
  else: 0   # what the legacy routine did with a SKU it did not know

func discounted(sum, lines: int): int {.raises: [].} =
  ## Three or more lines earn a tenth off, rounded down.
  if lines >= 3: sum - sum div 10 else: sum

func legacyTotal*(skus: seq[string]): int {.raises: [].} =
  ## The routine before the seam: the price list is inside.
  var sum = 0
  for s in skus:
    sum += hardWiredPrice(s)
  discounted(sum, skus.len)

func defaultSeam*(): Seam {.raises: [].} =
  ## The old wiring as a seam: the same list, but an unknown SKU is none, not 0.
  proc(sku: string): Option[int] {.noSideEffect, raises: [].} =
    if sku in ["apple", "pear", "fig"]: some(hardWiredPrice(sku)) else: none(int)

func total*(prices: Seam; skus: seq[string]): Result[int, PriceError] {.raises: [].} =
  ## The same arithmetic with the lookup handed in; the first unknown SKU is the error.
  var sum = 0
  for s in skus:
    let p = prices(s)
    if p.isNone:
      return err(int, PriceError(unknownSku: s))
    sum += p.get
  ok(discounted(sum, skus.len), PriceError)

func pin*(f: Total; inputs: seq[seq[string]]): Pins {.raises: [].} =
  ## Records what `f` does now, input by input.
  for i in inputs:
    result.add (input: i, output: f(i))

func firstDifference*(pins: Pins; f: Total): Option[int] {.raises: [].} =
  ## The index of the first pinned input on which `f` no longer gives the pinned output.
  for i, p in pins:
    if f(p.input) != p.output:
      return some(i)
  none(int)

func holds*(pins: Pins; f: Total): bool {.raises: [].} = firstDifference(pins, f).isNone
