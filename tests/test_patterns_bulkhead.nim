import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/patterns/bulkhead

const Names = ["alpha", "beta", "gamma"]

func three(a, b, c: int): Bulkhead {.raises: [].} =
  let r = initBulkhead([("alpha", a), ("beta", b), ("gamma", c)])
  doAssert r.isOk
  r.value

func nameOf(i: int): string {.raises: [].} = Names[i mod 3]

# SPEC: PAT-BULKHEAD-01
test "PAT-BULKHEAD-01 Given a compartment with a free permit, when acquired, then it is admitted and one more permit is in use":
  let outcome = check(pair(pair(intIn(1, 5), intIn(1, 5)), intIn(0, 2)), proc(x: ((int, int), int)): bool {.raises: [CatchableError].} =
    let b = three(x[0][0], x[0][1], 3)
    let name = nameOf(x[1])
    let (b2, a) = b.tryAcquire(name)
    a == aAdmitted and b2.inUse(name) == 1 and b2.available(name) == b.limit(name) - 1)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-BULKHEAD-02
test "PAT-BULKHEAD-02 Given a full compartment, when acquired, then it is refused and the bulkhead is unchanged":
  let b0 = three(1, 2, 3)
  let (b1, a1) = b0.tryAcquire("alpha")
  check a1 == aAdmitted
  let (b2, a2) = b1.tryAcquire("alpha")
  check a2 == aFull
  check b2 == b1

# SPEC: PAT-BULKHEAD-03
test "PAT-BULKHEAD-03 Given any operations on one compartment, when applied, then no other compartment changes":
  let outcome = check(pair(intIn(0, 2), seqOf(boolean(), 0, 30)), proc(x: (int, seq[bool])): bool {.raises: [CatchableError].} =
    var b = three(2, 3, 4)
    let name = nameOf(x[0])
    let before = b.usage
    for take in x[1]:
      if take: b = b.tryAcquire(name).bulkhead
      else:
        let r = b.release(name)
        if r.isOk: b = r.value
    let after = b.usage
    for i in 0 ..< before.len:
      if before[i][0] != name and before[i] != after[i]: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-BULKHEAD-04
test "PAT-BULKHEAD-04 Given any sequence of acquires and releases, when applied, then permits in use stay within 0 and the limit and admissions match the free permits":
  let outcome = check(seqOf(pair(intIn(0, 2), boolean()), 0, 60), proc(x: seq[(int, bool)]): bool {.raises: [CatchableError].} =
    var b = three(1, 2, 3)
    for (i, take) in x:
      let name = nameOf(i)
      if take:
        let free = b.available(name)
        let (next, a) = b.tryAcquire(name)
        if (a == aAdmitted) != (free > 0): return false
        b = next
      else:
        let r = b.release(name)
        if r.isOk: b = r.value
      for n in Names:
        if b.inUse(n) < 0 or b.inUse(n) > b.limit(n): return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-BULKHEAD-05
test "PAT-BULKHEAD-05 Given an admitted acquire, when the permit is released, then the bulkhead equals the one before":
  let outcome = check(pair(intIn(0, 2), intIn(0, 2)), proc(x: (int, int)): bool {.raises: [CatchableError].} =
    var b = three(3, 3, 3)
    let name = nameOf(x[0])
    for _ in 1 .. x[1]: b = b.tryAcquire(name).bulkhead
    let (b2, a) = b.tryAcquire(name)
    let back = b2.release(name)
    a == aAdmitted and back.isOk and back.value == b)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-BULKHEAD-06
test "PAT-BULKHEAD-06 Given nothing taken or an unknown name, when releasing or acquiring, then each gets its own answer":
  let b = three(1, 1, 1)
  check b.release("alpha").error == reNothingToRelease
  check b.release("delta").error == reUnknownCompartment
  let (b2, a) = b.tryAcquire("delta")
  check a == aUnknownCompartment
  check b2 == b
  check b.limit("delta") == 0
  check b.inUse("delta") == 0

# SPEC: PAT-BULKHEAD-07
test "PAT-BULKHEAD-07 Given invalid compartments, when the bulkhead is built, then each rule gets its own error":
  check initBulkhead(newSeq[(string, int)]()).error == seNoCompartments
  check initBulkhead([("a", 1), ("", 2)]).error == seEmptyName
  check initBulkhead([("a", 1), ("a", 2)]).error == seDuplicateName
  check initBulkhead([("a", 1), ("b", 0)]).error == seLimitNotPositive
  let good = initBulkhead([("b", 2), ("a", 1)])
  check good.isOk
  check good.value.usage == @[("a", 0), ("b", 0)]
  check good.value.limit("b") == 2

# SPEC: PAT-BULKHEAD-01
test "PAT-BULKHEAD-01 Given an admitted acquire, when the bulkheads are compared, then they differ in the permits in use, and in the limits":
  let b = three(2, 2, 3)
  let (b2, a) = b.tryAcquire("beta")
  check a == aAdmitted
  check b2 != b
  check b == three(2, 2, 3)
  check b != three(1, 2, 3)
  check b != three(2, 2, 4)
