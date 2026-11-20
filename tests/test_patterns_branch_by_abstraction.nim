import std/[unittest, options]
import propcheck
import nimcs/patterns/branch_by_abstraction

func itemsGen(): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(-500, 5000), 0, 8)

func poisoned(): Pricing {.raises: [].} =
  Pricing(subtotal: proc(cents: seq[int]): int {.noSideEffect, raises: [].} = 12345)

const Stages = [stOld, stShadow, stNew]

# SPEC: PAT-BRANCHBYABSTRACTION-01
test "PAT-BRANCHBYABSTRACTION-01 Given two implementations of one contract, when the stage moves, then the caller's total never changes":
  let outcome = check(pair(itemsGen(), intIn(0, 30)), proc(x: (seq[int], int)): bool {.raises: [CatchableError].} =
    let (items, tax) = x
    let expected = invoiceTotal(oldPricing(), items, tax)
    for st in Stages:
      if invoiceAt(st, oldPricing(), newPricing(), items, tax).total != expected: return false
      if invoiceAt(st, newPricing(), oldPricing(), items, tax).total != expected: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed
  check invoiceTotal(oldPricing(), @[1000, -50, 500], 10) == 1650   # a negative line counts as 0

# SPEC: PAT-BRANCHBYABSTRACTION-02
test "PAT-BRANCHBYABSTRACTION-02 Given a shadow stage, when run, then the old answer is returned and a mismatch is reported exactly when the two differ":
  let outcome = check(pair(itemsGen(), intIn(0, 30)), proc(x: (seq[int], int)): bool {.raises: [CatchableError].} =
    let (items, tax) = x
    var anyNegative = false
    for c in items:
      if c < 0: anyNegative = true
    let good = invoiceAt(stShadow, oldPricing(), newPricing(), items, tax)
    let drifted = invoiceAt(stShadow, oldPricing(), uncheckedPricing(), items, tax)
    let oldAnswer = invoiceTotal(oldPricing(), items, tax)
    good.total == oldAnswer and good.mismatch.isNone and
      drifted.total == oldAnswer and drifted.mismatch.isSome == anyNegative)
  checkpoint describe(outcome)
  check outcome.passed
  let seen = invoiceAt(stShadow, oldPricing(), uncheckedPricing(), @[100, -30], 0).mismatch
  check seen == some(Mismatch(oldTotal: 100, newTotal: 70))

# SPEC: PAT-BRANCHBYABSTRACTION-03
test "PAT-BRANCHBYABSTRACTION-03 Given the new and old stages, when run, then each answers with its own implementation whatever the other returns":
  let outcome = check(pair(itemsGen(), intIn(0, 30)), proc(x: (seq[int], int)): bool {.raises: [CatchableError].} =
    let (items, tax) = x
    invoiceAt(stNew, poisoned(), newPricing(), items, tax).total == invoiceTotal(newPricing(), items, tax) and
      invoiceAt(stOld, oldPricing(), poisoned(), items, tax).total == invoiceTotal(oldPricing(), items, tax) and
      invoiceAt(stOld, oldPricing(), poisoned(), items, tax).mismatch.isNone and
      invoiceAt(stNew, poisoned(), newPricing(), items, tax).mismatch.isNone)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-BRANCHBYABSTRACTION-04
test "PAT-BRANCHBYABSTRACTION-04 Given a stage, when advanced or retreated, then it moves one step and stops at its end":
  check advance(stOld) == stShadow
  check advance(stShadow) == stNew
  check advance(stNew) == stNew
  check retreat(stNew) == stShadow
  check retreat(stShadow) == stOld
  check retreat(stOld) == stOld
  for s in [stOld, stShadow]:
    check retreat(advance(s)) == s
