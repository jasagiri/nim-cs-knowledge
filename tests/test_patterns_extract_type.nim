import std/unittest
import propcheck
import nimcs/patterns/extract_type

proc money(minor: int; code: string): Money {.raises: [].} =
  let m = initMoney(minor, code)
  doAssert m.isOk
  m.value

# SPEC: PAT-EXTRACTTYPE-01
test "PAT-EXTRACTTYPE-01 Given two amounts in one currency, when added loose and as Money, then the results agree":
  let outcome = check(pair(pair(intIn(0, 100000), intIn(0, 100000)), pick(["JPY", "USD", "EUR"])),
      proc(x: ((int, int), string)): bool {.raises: [CatchableError].} =
    let ((a, b), code) = x
    let loose = addLoose(a, code, b, code)
    let sum = money(a, code).plus(money(b, code))
    sum.isOk and sum.value.minor == loose[0] and $sum.value.currency == loose[1])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-EXTRACTTYPE-02
test "PAT-EXTRACTTYPE-02 Given two currencies that differ, when added, then Money refuses and the loose code silently answers":
  let loose = addLoose(100, "JPY", 100, "USD")
  check loose == (200, "JPY")   # the wrong answer the extraction removes
  check money(100, "JPY").plus(money(100, "USD")).error == meCurrencyMismatch

# SPEC: PAT-EXTRACTTYPE-03
test "PAT-EXTRACTTYPE-03 Given any code and amount, when Money is built, then only known codes and non-negative amounts pass":
  let outcome = check(pair(intIn(-5, 5), stringOf("JPUSDER", 0, 3)),
      proc(x: (int, string)): bool {.raises: [CatchableError].} =
    let m = initMoney(x[0], x[1])
    let known = x[1] in ["JPY", "USD", "EUR"]
    if not known: m.isErr and m.error == meUnknownCurrency
    elif x[0] < 0: m.isErr and m.error == meNegative
    else: m.isOk and m.value.minor == x[0] and $m.value.currency == x[1])
  checkpoint describe(outcome)
  check outcome.passed
  check initMoney(-1, "XXX").error == meUnknownCurrency   # the code is checked first

# SPEC: PAT-EXTRACTTYPE-04
test "PAT-EXTRACTTYPE-04 Given Money values of one currency, when added, then it is commutative, associative and zero is the identity":
  let outcome = check(pair(intIn(0, 9999), pair(intIn(0, 9999), intIn(0, 9999))),
      proc(x: (int, (int, int))): bool {.raises: [CatchableError].} =
    let a = money(x[0], "EUR")
    let b = money(x[1][0], "EUR")
    let c = money(x[1][1], "EUR")
    let zero = money(0, "EUR")
    a.plus(b) == b.plus(a) and
      a.plus(b).value.plus(c) == a.plus(b.plus(c).value) and
      a.plus(zero).value == a)
  checkpoint describe(outcome)
  check outcome.passed
