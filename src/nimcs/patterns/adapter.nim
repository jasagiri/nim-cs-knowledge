## Adapter as a function between two types.
##
## The OO pattern wraps an object with an incompatible interface so that existing client code can
## use it. In Nim the interface is a type, so the adapter is a `func` that converts the old shape to
## the new one; adapting a source of values is mapping that func over it. Here a legacy schedule
## source returns "HH:MM" strings and the new code wants `Minutes` since midnight. Use it at the
## boundary where a foreign shape enters; do not let the foreign shape leak further in.

import nimcs/fp/result

type
  Minutes* = distinct int

  AdaptError* = enum
    aeBadLength, aeBadSeparator, aeBadDigit, aeOutOfRange

  LegacySource* = proc(): seq[string] {.noSideEffect, raises: [].}

func `==`*(a, b: Minutes): bool {.borrow.}

func digit(c: char): int {.raises: [].} =
  if c in {'0' .. '9'}: ord(c) - ord('0') else: -1

func fromLegacy*(s: string): Result[Minutes, AdaptError] {.raises: [].} =
  ## Parses "HH:MM"; every malformed input is a specific error, never an exception.
  if s.len != 5:
    err(Minutes, aeBadLength)
  elif s[2] != ':':
    err(Minutes, aeBadSeparator)
  else:
    let (a, b, c, d) = (digit(s[0]), digit(s[1]), digit(s[3]), digit(s[4]))
    if a < 0 or b < 0 or c < 0 or d < 0:
      err(Minutes, aeBadDigit)
    else:
      let h = a * 10 + b
      let m = c * 10 + d
      if h > 23 or m > 59: err(Minutes, aeOutOfRange)
      else: ok(Minutes(h * 60 + m), AdaptError)

func toLegacy*(m: Minutes): string {.raises: [].} =
  ## Inverse of `fromLegacy` on `0 .. 1439`.
  let v = int(m)
  let h = v div 60
  let mm = v mod 60
  $(h div 10) & $(h mod 10) & ":" & $(mm div 10) & $(mm mod 10)

func adaptAll*(src: LegacySource): Result[seq[Minutes], AdaptError] {.raises: [].} =
  ## Adapts a whole source; the first bad entry stops the conversion.
  var acc: seq[Minutes] = @[]
  for s in src():
    let r = fromLegacy(s)
    if r.isErr:
      return err(seq[Minutes], r.error)
    acc.add(r.value)
  ok(acc, AdaptError)
