import std/[unittest, options]
import propcheck
import nimcs/patterns/strategy

func prices(xs: seq[int]): seq[Cents] {.raises: [].} =
  for x in xs: result.add Cents(x)

func fixedRules(): seq[PriceRule] {.raises: [].} =
  @[PriceRule(noDiscount), percentOff(10), percentOff(50), flatOff(300)]

# SPEC: GOF-STRATEGY-01
test "GOF-STRATEGY-01 Given any items, when checked out with noDiscount, then the total is their sum":
  let outcome = check(seqOf(intIn(0, 5000), 0, 8), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    var s = 0
    for x in xs: s += x
    checkout(prices(xs), noDiscount) == Cents(s))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-STRATEGY-02
test "GOF-STRATEGY-02 Given any price and percentage, when percentOff applies, then the result lies between zero and the price":
  let outcome = check(pair(intIn(0, 100000), intIn(-50, 150)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    let r = percentOff(p[1])(Cents(p[0]))
    Cents(0) <= r and r <= Cents(p[0]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-STRATEGY-02
test "GOF-STRATEGY-02 Given a price, when flatOff applies, then the result is never negative and never above the price":
  let outcome = check(pair(intIn(0, 100000), intIn(-50, 200000)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    let r = flatOff(p[1])(Cents(p[0]))
    Cents(0) <= r and r <= Cents(p[0]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-STRATEGY-03
test "GOF-STRATEGY-03 Given two rules, when composed with then, then the result equals applying them one after the other":
  let outcome = check(pair(pair(intIn(0, 100000), intIn(0, 100)), intIn(0, 5000)), proc(p: ((int, int), int)): bool {.raises: [CatchableError].} =
    let a = percentOff(p[0][1])
    let b = flatOff(p[1])
    let x = Cents(p[0][0])
    a.then(b)(x) == b(a(x)))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-STRATEGY-04
test "GOF-STRATEGY-04 Given any items, when cheapest of several rules is taken, then it is no more than each rule's price":
  let outcome = check(seqOf(intIn(0, 5000), 0, 8), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let rules = fixedRules()
    let total = checkout(prices(xs), noDiscount)
    let best = cheapest(rules, total)
    var ok = true
    for r in rules:
      if not (best <= r(total)): ok = false
    ok and best <= total)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-STRATEGY-04
test "GOF-STRATEGY-04 Given no rules, when cheapest is asked, then the price itself is returned":
  check cheapest(newSeq[PriceRule](), Cents(700)) == Cents(700)

# SPEC: GOF-STRATEGY-05
test "GOF-STRATEGY-05 Given a rule, when passed as a value or as a generic parameter, then both give the same total":
  let outcome = check(pair(seqOf(intIn(0, 5000), 0, 8), intIn(0, 100)), proc(p: (seq[int], int)): bool {.raises: [CatchableError].} =
    let rule = percentOff(p[1])
    checkout(prices(p[0]), rule) == total2(prices(p[0]), rule))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-STRATEGY-06
test "GOF-STRATEGY-06 Given a negative amount, when the cents smart constructor is used, then it yields none":
  check cents(-1).isNone
  check cents(0).get == Cents(0)
  check cents(1999).get.value == 1999

# SPEC: GOF-STRATEGY-07
test "GOF-STRATEGY-07 Given 10 percent off 1999, when applied, then the discount rounds down to 1800 cents":
  check percentOff(10)(Cents(1999)) == Cents(1800)

# SPEC: GOF-STRATEGY-08
test "GOF-STRATEGY-08 Given prices up to high(int), when rules apply and items are summed, then nothing overflows and bounds hold":
  let outcome = check(pair(intIn(0, high(int)), intIn(-50, 150)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    let r = percentOff(p[1])(Cents(p[0]))
    let f = flatOff(p[1])(Cents(p[0]))
    Cents(0) <= r and r <= Cents(p[0]) and Cents(0) <= f and f <= Cents(p[0]))
  checkpoint describe(outcome)
  check outcome.passed
  check percentOff(10)(Cents(high(int))) == Cents(high(int) - high(int) div 10 - ((high(int) mod 100) * 10) div 100)
  check checkout([Cents(high(int)), Cents(high(int))], noDiscount) == Cents(high(int))
  check checkout([Cents(high(int)), Cents(5)], flatOff(0)) == Cents(high(int))
