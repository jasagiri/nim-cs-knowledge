import std/[unittest, strutils]
import propcheck
import nimcs/fp/[result, phantom_type]

type
  User = object
  Order = object

func qs(): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(-50, 50), 3, 3)

# SPEC: FP-PHANTOMTYPE-01
test "FP-PHANTOMTYPE-01 Given ids of the same kind, when compared or unwrapped, then they behave as ints; given different kinds, then they do not mix":
  check idOf[User](3) == idOf[User](3)
  check idOf[User](3) < idOf[User](4)
  check not compiles(idOf[User](3) == idOf[Order](3))
  check not compiles(block:
    func takesOrder(o: Id[Order]): int = raw(o)
    takesOrder(idOf[User](1)))
  let outcome = check(pair(intIn(-100, 100), intIn(-100, 100)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    raw(idOf[User](p[0])) == p[0] and (idOf[Order](p[0]) < idOf[Order](p[1])) == (p[0] < p[1]) and
      (idOf[Order](p[0]) == idOf[Order](p[1])) == (p[0] == p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-PHANTOMTYPE-02
test "FP-PHANTOMTYPE-02 Given quantities of one unit, when added, subtracted or scaled, then the arithmetic laws hold; given two units, then they do not add":
  check not compiles(qty[Meter](1) + qty[Second](1))
  check not compiles(qty[Meter](1) == qty[Centimeter](1))
  check not compiles(qty[Meter](1) * qty[Meter](2))
  check not compiles(qty[Meter](1) + 2)
  let outcome = check(qs(), proc(t: seq[int]): bool {.raises: [CatchableError].} =
    let (a, b, c) = (qty[Meter](t[0]), qty[Meter](t[1]), qty[Meter](t[2]))
    a + b == b + a and (a + b) + c == a + (b + c) and a + qty[Meter](0) == a and
      (a + b) - b == a and amount((a + b).scaled(3)) == amount(a.scaled(3) + b.scaled(3)))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-PHANTOMTYPE-03
test "FP-PHANTOMTYPE-03 Given meters, when converted to centimeters and back, then the value returns; given a non-multiple of 100, then the conversion is an error":
  check toCentimeters(qty[Meter](2)) == qty[Centimeter](200)
  check toMetersExact(qty[Centimeter](150)) == err(Quantity[Meter], "not a whole number of meters")
  let outcome = check(intIn(-1000, 1000), proc(m: int): bool {.raises: [CatchableError].} =
    toMetersExact(toCentimeters(qty[Meter](m))) == ok(qty[Meter](m), string) and
      toMetersExact(qty[Centimeter](m)).isOk == (m mod 100 == 0))
  checkpoint describe(outcome)
  check outcome.passed

func referenceAccepts(s: string): bool {.raises: [].} =
  let parts = s.split('@')
  if parts.len != 2 or parts[0].len == 0:
    return false
  let d = parts[1]
  for i in 1 ..< d.high:
    if d[i] == '.':
      return true
  false

# SPEC: FP-PHANTOMTYPE-04
test "FP-PHANTOMTYPE-04 Given raw text, when validated, then valid addresses become Validated with the same text and domain, and invalid ones are errors":
  check validateEmail(rawEmail("ann@example.com")).isOk
  check validateEmail(rawEmail("ann@example")).isErr
  check validateEmail(rawEmail("@example.com")).isErr
  check validateEmail(rawEmail("a@@b.co")).isErr
  check validateEmail(rawEmail("a@com.")).isErr
  check validateEmail(rawEmail("a@.com")).isErr
  let outcome = check(stringOf("ab@.", 0, 8), proc(s: string): bool {.raises: [CatchableError].} =
    let v = validateEmail(rawEmail(s))
    v.isOk == referenceAccepts(s) and
      (not v.isOk or (text(v.value) == s and domainOf(v.value) == s.split('@')[1])))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-PHANTOMTYPE-05
test "FP-PHANTOMTYPE-05 Given a raw address, when passed where a validated one is required, then it does not compile":
  check not compiles(domainOf(rawEmail("a@b.co")))
  check compiles(domainOf(validateEmail(rawEmail("a@b.co")).value))

# SPEC: FP-PHANTOMTYPE-06
test "FP-PHANTOMTYPE-06 Given phantom parameters, when sizes are compared, then they cost nothing at run time":
  check sizeof(Id[User]) == sizeof(int)
  check sizeof(Quantity[Meter]) == sizeof(int)
  check sizeof(Email[Raw]) == sizeof(string)
  check sizeof(Email[Validated]) == sizeof(string)

# SPEC: FP-PHANTOMTYPE-07
test "FP-PHANTOMTYPE-07 Given a distinct phantom type, when a caller converts explicitly, then the guard is bypassed":
  # The phantom parameter stops accidents, not forgery: use an object with a private field and a
  # smart constructor when the value must be unforgeable.
  check compiles(Email[Validated]("not an address"))
  let forged = Email[Validated]("not an address")
  check domainOf(forged) == ""
