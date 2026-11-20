## Branch by abstraction: replace an implementation inside the trunk, behind an interface, in small steps.
##
## A long-lived branch for a replacement drifts from the trunk until nobody can merge it. Branch by
## abstraction keeps one trunk: first the callers are moved behind an abstraction (here a record of
## procs, `Pricing`) that the old implementation fills, then the new implementation is written
## behind the same abstraction, then a stage value says which one answers: old, shadow (the old
## answers while both run and a mismatch is reported) or new. Callers never change when the stage
## does. The stage is a plain value moved by `advance` and `retreat`, so going forward, going
## back and "the old one is no longer consulted" are functions with laws. Use it for a replacement
## that cannot land in one commit and has no seam at the network edge (that is the strangler fig);
## remove the abstraction's losing side when the stage reaches `stNew` for good.

import std/options

type
  Stage* = enum
    stOld, stShadow, stNew

  Pricing* = object
    ## The abstraction. Contract: the sum of the line amounts in cents, a negative line counting as 0.
    subtotal*: proc(cents: seq[int]): int {.noSideEffect, raises: [].}

  Mismatch* = object
    oldTotal*, newTotal*: int

  Answer* = tuple[total: int, mismatch: Option[Mismatch]]

func oldPricing*(): Pricing {.raises: [].} =
  Pricing(subtotal: proc(cents: seq[int]): int {.noSideEffect, raises: [].} =
    var sum = 0
    for c in cents:
      if c > 0: sum += c
    sum)

func newPricing*(): Pricing {.raises: [].} =
  ## The replacement: the same contract, written another way.
  Pricing(subtotal: proc(cents: seq[int]): int {.noSideEffect, raises: [].} =
    var sum = 0
    for c in cents:
      sum += max(c, 0)
    sum)

func uncheckedPricing*(): Pricing {.raises: [].} =
  ## A replacement that forgot the clamp; the shadow stage exists to find this before users do.
  Pricing(subtotal: proc(cents: seq[int]): int {.noSideEffect, raises: [].} =
    var sum = 0
    for c in cents:
      sum += c
    sum)

func invoiceTotal*(p: Pricing; cents: seq[int]; taxPercent: int): int {.raises: [].} =
  ## A caller. It knows the abstraction and nothing about which implementation fills it.
  let sub = p.subtotal(cents)
  sub + sub * taxPercent div 100

func select*(stage: Stage; old, replacement: Pricing): Pricing {.raises: [].} =
  ## Only `stNew` consults the replacement for the answer; the shadow stage answers with the old.
  case stage
  of stOld, stShadow: old
  of stNew: replacement

func compare*(old, replacement: Pricing; cents: seq[int]): Option[Mismatch] {.raises: [].} =
  let (a, b) = (old.subtotal(cents), replacement.subtotal(cents))
  if a == b: none(Mismatch) else: some(Mismatch(oldTotal: a, newTotal: b))

func invoiceAt*(stage: Stage; old, replacement: Pricing; cents: seq[int]; taxPercent: int): Answer {.raises: [].} =
  ## The answer at a stage; the mismatch is looked for only while the stage is `stShadow`.
  let mismatch = if stage == stShadow: compare(old, replacement, cents) else: none(Mismatch)
  (total: invoiceTotal(select(stage, old, replacement), cents, taxPercent), mismatch: mismatch)

func advance*(s: Stage): Stage {.raises: [].} =
  case s
  of stOld: stShadow
  of stShadow, stNew: stNew

func retreat*(s: Stage): Stage {.raises: [].} =
  case s
  of stOld, stShadow: stOld
  of stNew: stShadow
