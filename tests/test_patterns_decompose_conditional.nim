import std/unittest
import propcheck
import nimcs/patterns/decompose_conditional

proc visitors(): Gen[(int, (bool, (int, int)))] {.raises: [ValueError].} =
  pair(intIn(0, 100), pair(boolean(), pair(intIn(0, 6), intIn(0, 23))))

func toVisitor(x: (int, (bool, (int, int)))): Visitor {.raises: [].} =
  Visitor(age: x[0], isStudent: x[1][0], weekday: x[1][1][0], hour: x[1][1][1])

# SPEC: PAT-DECOMPOSECONDITIONAL-01
test "PAT-DECOMPOSECONDITIONAL-01 Given any visitor, when priced before and after decomposition, then the prices are equal":
  let outcome = check(visitors(), proc(x: (int, (bool, (int, int)))): bool {.raises: [CatchableError].} =
    let v = toVisitor(x)
    v.priceBefore == v.price)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-DECOMPOSECONDITIONAL-02
test "PAT-DECOMPOSECONDITIONAL-02 Given any visitor, when the tier is computed, then each rule implies its tier and free beats reduced":
  let outcome = check(visitors(), proc(x: (int, (bool, (int, int)))): bool {.raises: [CatchableError].} =
    let v = toVisitor(x)
    if v.isChild and v.tierOf != tFree: return false
    if v.isSenior and v.isWeekday and v.tierOf != tFree: return false
    not ((v.isDaytimeStudent or v.isEvening) and v.tierOf == tFull))
  checkpoint describe(outcome)
  check outcome.passed
  # A weekday senior is also eligible for the reduced rate, and pays nothing.
  check Visitor(age: 70, isStudent: false, weekday: 2, hour: 21).tierOf == tFree

# SPEC: PAT-DECOMPOSECONDITIONAL-03
test "PAT-DECOMPOSECONDITIONAL-03 Given the boundaries of each clause, when priced, then both sides of every boundary give the documented tier":
  check Visitor(age: 5, weekday: 6, hour: 12).tierOf == tFree
  check Visitor(age: 6, weekday: 6, hour: 12).tierOf == tFull
  check Visitor(age: 65, weekday: 4, hour: 12).tierOf == tFree
  check Visitor(age: 65, weekday: 5, hour: 12).tierOf == tReduced
  check Visitor(age: 25, isStudent: true, weekday: 6, hour: 16).tierOf == tReduced
  check Visitor(age: 26, isStudent: true, weekday: 6, hour: 16).tierOf == tFull
  check Visitor(age: 25, isStudent: true, weekday: 6, hour: 17).tierOf == tFull
  check Visitor(age: 30, weekday: 6, hour: 19).tierOf == tFull
  check Visitor(age: 30, weekday: 6, hour: 20).tierOf == tReduced

# SPEC: PAT-DECOMPOSECONDITIONAL-04
test "PAT-DECOMPOSECONDITIONAL-04 Given each tier, when its price is asked, then free is below reduced is below full":
  check tFree.priceOf == 0
  check tReduced.priceOf == ReducedPrice
  check tFull.priceOf == FullPrice
  check tFree.priceOf < tReduced.priceOf
  check tReduced.priceOf < tFull.priceOf
