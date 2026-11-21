## Phantom types: a type parameter that is never stored, only checked (ADR-NCK-0002 S3).
##
## `Id[T]` is an `int` at run time and a different type for each `T`, so a user id cannot be passed
## where an order id is expected. `Quantity[U]` carries its unit in the type: lengths add to
## lengths, never to durations. `Email[S]` records in the type whether the text was validated, so a
## routine that needs a valid address (`domainOf`) cannot be handed a raw one. The parameter costs
## nothing at run time. It is built with `distinct`, so a conversion such as `Email[Validated]("x")`
## still compiles anywhere: the phantom parameter stops accidents, not a caller who forges it. When
## the value must be unforgeable, hide the field in an object and export only the smart
## constructor (see `smart_constructor.nim`).

import nimcs/fp/result

type
  Id*[T] = distinct int
    ## An identifier of something of kind `T`; `T` is only a label.

  Meter* = object
    ## Unit tag for lengths in meters.
  Centimeter* = object
    ## Unit tag for lengths in centimeters.
  Second* = object
    ## Unit tag for durations.

  Quantity*[U] = distinct int
    ## An exact whole amount measured in unit `U`.

  Raw* = object
    ## Tag: text that has not been checked.
  Validated* = object
    ## Tag: text that `validateEmail` accepted.

  Email*[S] = distinct string
    ## An e-mail address in state `S` (`Raw` or `Validated`).

func idOf*[T](n: int): Id[T] {.raises: [].} =
  ## Labels a number as an id of kind `T`.
  Id[T](n)

func raw*[T](id: Id[T]): int {.raises: [].} =
  ## The number inside the id.
  int(id)

func `==`*[T](a, b: Id[T]): bool {.raises: [].} = int(a) == int(b)

func `<`*[T](a, b: Id[T]): bool {.raises: [].} = int(a) < int(b)

func qty*[U](n: int): Quantity[U] {.raises: [].} =
  ## An amount of `n` units `U`.
  Quantity[U](n)

func amount*[U](q: Quantity[U]): int {.raises: [].} =
  ## The number inside the quantity.
  int(q)

func `+`*[U](a, b: Quantity[U]): Quantity[U] {.raises: [].} = Quantity[U](int(a) + int(b))

func `-`*[U](a, b: Quantity[U]): Quantity[U] {.raises: [].} = Quantity[U](int(a) - int(b))

func `==`*[U](a, b: Quantity[U]): bool {.raises: [].} = int(a) == int(b)

func scaled*[U](q: Quantity[U]; factor: int): Quantity[U] {.raises: [].} =
  ## The amount multiplied by a plain number; the unit is unchanged.
  Quantity[U](int(q) * factor)

func toCentimeters*(m: Quantity[Meter]): Quantity[Centimeter] {.raises: [].} =
  ## The only way to turn meters into centimeters: the unit change is explicit.
  Quantity[Centimeter](int(m) * 100)

func toMetersExact*(cm: Quantity[Centimeter]): Result[Quantity[Meter], string] {.raises: [].} =
  ## Whole meters, or an error when the centimeters are not a multiple of 100 (no silent rounding).
  if int(cm) mod 100 == 0: ok(Quantity[Meter](int(cm) div 100), string)
  else: err(Quantity[Meter], "not a whole number of meters")

func rawEmail*(text: string): Email[Raw] {.raises: [].} =
  ## Wraps unchecked text; says nothing about its validity.
  Email[Raw](text)

func validateEmail*(e: Email[Raw]): Result[Email[Validated], string] {.raises: [].} =
  ## Accepts text with exactly one `@`, a non-empty part before it and a part after it that has a
  ## `.` which is neither its first nor its last character. This is a teaching rule, not RFC 5322.
  let s = string(e)
  var at = -1
  var ats = 0
  for i, c in s:
    if c == '@':
      inc ats
      at = i
  if ats != 1 or at == 0:
    return err(Email[Validated], "needs one @ and a name before it")
  let domain = s[at + 1 .. ^1]
  var innerDot = false
  for i, c in domain:
    if c == '.' and i > 0 and i < domain.high:
      innerDot = true
  if not innerDot:
    return err(Email[Validated], "domain needs a dot between two parts")
  ok(Email[Validated](s), string)

func domainOf*(e: Email[Validated]): string {.raises: [].} =
  ## The part after `@`. Only a validated address is accepted, so there is no failure case.
  let s = string(e)
  for i in 0 ..< s.len:
    if s[i] == '@':
      return s[i + 1 .. ^1]
  ""

func text*[S](e: Email[S]): string {.raises: [].} =
  ## The text of an address in any state.
  string(e)
