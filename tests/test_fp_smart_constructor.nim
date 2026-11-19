import std/[unittest, strutils]
import propcheck
import nimcs/fp/[result, smart_constructor]

const nameAlphabet = "abcdefghijklmnopqrstuvwxyz0123456789_"

# SPEC: FP-SMARTCONSTRUCTOR-01
test "FP-SMARTCONSTRUCTOR-01 Given text of the allowed alphabet and length, when parseUsername, then it is ok and the value is the text":
  let outcome = check(stringOf(nameAlphabet, minNameLen, maxNameLen), proc(s: string): bool {.raises: [CatchableError].} =
    let r = parseUsername(s)
    r.isOk and r.value.value == s)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-SMARTCONSTRUCTOR-02
test "FP-SMARTCONSTRUCTOR-02 Given bad text, when parseUsername, then the error names what is wrong":
  check parseUsername("ab").error == tooShort
  check parseUsername("a".repeat(17)).error == tooLong
  check parseUsername("bob smith").error == badCharacter
  check parseUsername("bob-1").error == badCharacter
  check parseUsername("  ").error == tooShort

# SPEC: FP-SMARTCONSTRUCTOR-03
test "FP-SMARTCONSTRUCTOR-03 Given any text, when a parsed username is parsed again from its value, then it is the same username":
  let outcome = check(stringOf(nameAlphabet & "ABC -", 0, 20), proc(s: string): bool {.raises: [CatchableError].} =
    let r = parseUsername(s)
    not r.isOk or parseUsername(r.value.value) == r)
  checkpoint describe(outcome)
  check outcome.passed
  check parseUsername("  Alice_1 ").value.value == "alice_1"

# SPEC: FP-SMARTCONSTRUCTOR-04
test "FP-SMARTCONSTRUCTOR-04 Given any integer, when parseQuantity, then it is ok exactly for 1 to 1000 and the value round-trips":
  let outcome = check(intIn(-50, 1100), proc(n: int): bool {.raises: [CatchableError].} =
    let r = parseQuantity(n)
    if n >= 1 and n <= 1000: r.isOk and r.value.value == n
    else: r.isErr and r.error == outOfRange)
  checkpoint describe(outcome)
  check outcome.passed
  check parseQuantity(low(int)).error == outOfRange
  check parseQuantity(high(int)).error == outOfRange

# SPEC: FP-SMARTCONSTRUCTOR-05
test "FP-SMARTCONSTRUCTOR-05 Given text, when parseQuantityText, then numbers are parsed, spaces ignored, and other text is notANumber":
  check parseQuantityText(" 42 ").value.value == 42
  check parseQuantityText("abc").error == notANumber
  check parseQuantityText("").error == notANumber
  check parseQuantityText("12x").error == notANumber
  check parseQuantityText("99999999999999999999").error == notANumber
  check parseQuantityText("0").error == outOfRange
  check parseQuantityText("1001").error == outOfRange

# SPEC: FP-SMARTCONSTRUCTOR-06
test "FP-SMARTCONSTRUCTOR-06 Given two quantities, when plus, then the total stays in range or is outOfRange":
  let a = parseQuantity(600).value
  let b = parseQuantity(300).value
  check a.plus(b).value.value == 900
  check a.plus(a).error == outOfRange
  let outcome = check(pair(intIn(1, 1000), intIn(1, 1000)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    let r = plus(parseQuantity(p[0]).value, parseQuantity(p[1]).value)
    (p[0] + p[1] <= 1000) == r.isOk)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-SMARTCONSTRUCTOR-07
test "FP-SMARTCONSTRUCTOR-07 Given an order with two bad fields, when parseOrder, then the first failing field decides the error":
  check parseOrder("ab", 0).error == tooShort
  check parseOrder("alice", 0).error == outOfRange
  let good = parseOrder("Alice", 3)
  check good.isOk
  check good.value.who.value == "alice"
  check good.value.qty.value == 3

# SPEC: FP-SMARTCONSTRUCTOR-08
test "FP-SMARTCONSTRUCTOR-08 Given the sealed types, when built or mixed outside the module, then the compiler refuses":
  let q = parseQuantity(5).value
  let u = parseUsername("alice").value
  check not compiles(q + q)
  check not compiles(block:
    let n: int = q
    n)
  check not compiles(block:
    let s: string = u
    s)
  check not compiles(q == u)
  # No way to forge a value or to leave one unset:
  check not compiles(Quantity(n: 5000))
  check not compiles(Username(raw: "x"))
  check not compiles(Quantity(5000))
  check not compiles(block:
    var unset: Quantity
    unset)
  check not compiles(Order())
  check compiles(Order(who: u, qty: q))
