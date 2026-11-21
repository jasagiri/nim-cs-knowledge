import std/unittest
import propcheck
import nimcs/patterns/replace_conditional_with_polymorphism

func genFlat(x: (int, (int, int))): FlatParcel {.raises: [].} =
  let k = case x[0]
    of 0: kStandard
    of 1: kExpress
    else: kPickup
  FlatParcel(kind: k, weightG: x[1][0], distanceKm: x[1][1])

proc flats(): Gen[(int, (int, int))] {.raises: [ValueError].} =
  pair(intIn(0, 2), pair(intIn(-50, 5000), intIn(-20, 900)))

# SPEC: PAT-REPLACECONDITIONALWITHPOLYMORPHISM-01
test "PAT-REPLACECONDITIONALWITHPOLYMORPHISM-01 Given any flat parcel, when costed before and as a variant, then the costs are equal":
  let outcome = check(flats(), proc(x: (int, (int, int))): bool {.raises: [CatchableError].} =
    let p = genFlat(x)
    p.costBefore == p.toParcel.cost)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-REPLACECONDITIONALWITHPOLYMORPHISM-02
test "PAT-REPLACECONDITIONALWITHPOLYMORPHISM-02 Given any flat parcel, when costed before and as a record of procs, then the costs are equal":
  let outcome = check(flats(), proc(x: (int, (int, int))): bool {.raises: [CatchableError].} =
    let p = genFlat(x)
    p.costBefore == p.toTariff.cost)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-REPLACECONDITIONALWITHPOLYMORPHISM-03
test "PAT-REPLACECONDITIONALWITHPOLYMORPHISM-03 Given a list of parcels, when totalled, then the total is the sum of the old costs and a pickup adds nothing":
  let outcome = check(seqOf(pair(intIn(0, 2), pair(intIn(0, 3000), intIn(0, 500))), 0, 8),
      proc(xs: seq[(int, (int, int))]): bool {.raises: [CatchableError].} =
    var parcels: seq[Parcel]
    var expected = 0
    for x in xs:
      let p = genFlat(x)
      parcels.add p.toParcel
      expected += p.costBefore
    parcels.total == expected and
      (parcels & @[Parcel(kind: kPickup)]).total == parcels.total)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-REPLACECONDITIONALWITHPOLYMORPHISM-04
test "PAT-REPLACECONDITIONALWITHPOLYMORPHISM-04 Given known parcels, when costed, then the cents are those of the rate card":
  check standard(250).cost == 9            # 3 started hundreds
  check Parcel(kind: kStandard, weightG: 250).cost == 9
  check express(100, 10).cost == 500 + 6 + 20
  check Parcel(kind: kExpress, expressWeightG: 100, distanceKm: 10).cost == 526
  check pickup().cost == 0
  check FlatParcel(kind: kStandard, weightG: -5).costBefore == 0

# SPEC: PAT-REPLACECONDITIONALWITHPOLYMORPHISM-05
test "PAT-REPLACECONDITIONALWITHPOLYMORPHISM-05 Given a case over the kinds, when one kind is left out, then it does not compile":
  func complete(p: Parcel): int {.raises: [].} =
    case p.kind
    of kStandard: 1
    of kExpress: 2
    of kPickup: 3
  check complete(Parcel(kind: kPickup)) == 3
  check not compiles(
    block:
      func partial(p: Parcel): int {.raises: [].} =
        case p.kind
        of kStandard: 1
        of kExpress: 2
      partial(Parcel(kind: kPickup)))
