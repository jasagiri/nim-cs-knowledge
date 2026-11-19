## Smart constructors: parse once, then carry a type that cannot be wrong (ADR-NCK-0002 S2, S3).
##
## `Username` and `Quantity` are objects with a private field and `{.requiresInit.}`. Outside this
## module there is no way to write `Quantity(...)` or `var q: Quantity` (an unset one would hold
## 0, out of range): the only routines that build them are `parseUsername`, `parseQuantity` and
## `parseQuantityText`, and each returns a `Result`, so a caller cannot get a value without
## handling the failure. Every function that takes a `Quantity` can then rely on the range without
## checking again ("parse, don't validate"). `parseOrder` shows the railway: the first failing
## field decides the error.
##
## A plain `distinct int` is not enough for this: `distinct` stops accidental mixing with other
## types, but `Quantity(5000)` still compiles anywhere and a default value is 0. Use `distinct`
## for units and identifiers that carry no rule; use a sealed object (as here) when the type must
## guarantee a rule. Read a field of a `Result` only after checking `isOk` (or use `valueOr`):
## `.value` on an error raises `FieldDefect`.

import std/strutils
import nimcs/fp/result

type
  ParseError* = enum
    tooShort, tooLong, badCharacter, outOfRange, notANumber

  Username* {.requiresInit.} = object
    ## 3 to 16 characters from `a-z`, `0-9`, `_`; always lower case.
    raw: string
  Quantity* {.requiresInit.} = object
    ## A whole number from 1 to 1000.
    n: int

  Order* {.requiresInit.} = object
    who*: Username
    qty*: Quantity

const
  minNameLen* = 3
  maxNameLen* = 16
  minQuantity* = 1
  maxQuantity* = 1000

func `==`*(a, b: Username): bool {.raises: [].} = a.raw == b.raw
func `==`*(a, b: Quantity): bool {.raises: [].} = a.n == b.n
func `$`*(u: Username): string {.raises: [].} = u.raw
func `$`*(q: Quantity): string {.raises: [].} = $q.n

func value*(u: Username): string {.raises: [].} = u.raw
func value*(q: Quantity): int {.raises: [].} = q.n

func parseUsername*(raw: string): Result[Username, ParseError] {.raises: [].} =
  ## Trims, lower-cases, then checks length and alphabet. Parsing the text of a parsed
  ## username gives the same username back.
  let s = raw.strip.toLowerAscii
  if s.len < minNameLen: return err(Username, tooShort)
  if s.len > maxNameLen: return err(Username, tooLong)
  for c in s:
    if c notin {'a'..'z', '0'..'9', '_'}:
      return err(Username, badCharacter)
  ok(Username(raw: s), ParseError)

func parseQuantity*(n: int): Result[Quantity, ParseError] {.raises: [].} =
  ## Accepts exactly `minQuantity .. maxQuantity`.
  if n < minQuantity or n > maxQuantity: err(Quantity, outOfRange)
  else: ok(Quantity(n: n), ParseError)

func parseQuantityText*(raw: string): Result[Quantity, ParseError] {.raises: [].} =
  ## Like `parseQuantity` for text; text that is not a whole number (or does not fit an `int`)
  ## is `notANumber`.
  var n = 0
  try:
    n = parseInt(raw.strip)
  except ValueError:
    return err(Quantity, notANumber)
  parseQuantity(n)

func plus*(a, b: Quantity): Result[Quantity, ParseError] {.raises: [].} =
  ## Adds two quantities; a total above `maxQuantity` is `outOfRange`, not a wrapped value.
  parseQuantity(a.n + b.n)

func parseOrder*(who: string; qty: int): Result[Order, ParseError] {.raises: [].} =
  ## The username is checked first; the quantity only if the username was fine.
  parseUsername(who).flatMap(proc(u: Username): Result[Order, ParseError] {.noSideEffect, raises: [].} =
    parseQuantity(qty).map(proc(q: Quantity): Order {.noSideEffect, raises: [].} =
      Order(who: u, qty: q)))
