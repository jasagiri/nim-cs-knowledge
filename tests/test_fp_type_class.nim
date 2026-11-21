import std/[unittest, options, algorithm, sequtils]
import propcheck
import nimcs/fp/type_class

type
  Version = object
    major, minor: int
  Meters = distinct int
  Clock = object
    ## A broken instance: `<` looks only at `tick mod 3`, `==` at the whole value.
    tick: int
  NoOrder = object
    a: int

func `<`(a, b: Version): bool {.raises: [].} = (a.major, a.minor) < (b.major, b.minor)
func `==`(a, b: Version): bool {.raises: [].} = a.major == b.major and a.minor == b.minor
func `<`(a, b: Meters): bool {.borrow.}
func `==`(a, b: Meters): bool {.borrow.}
func `<`(a, b: Clock): bool {.raises: [].} = a.tick mod 3 < b.tick mod 3
func `==`(a, b: Clock): bool {.raises: [].} = a.tick == b.tick

func inc1(x: int): int {.raises: [].} = x + 1

func ints(): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(-20, 20), 0, 10)
func versions(): Gen[Version] {.raises: [ValueError].} =
  pair(intIn(0, 3), intIn(0, 3)).map(proc(p: (int, int)): Version {.raises: [].} =
    Version(major: p[0], minor: p[1]))

# SPEC: FP-TYPECLASS-01
test "FP-TYPECLASS-01 Given an orderable type, when maxOf and minOf run, then they give the ends of the sorted sequence or none when empty":
  check maxOf(newSeq[int]()).isNone
  check minOf(newSeq[string]()).isNone
  check maxOf(@["pear", "apple"]) == some("pear")
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let s = xs.sorted
    if xs.len == 0: maxOf(xs).isNone and minOf(xs).isNone
    else: maxOf(xs) == some(s[^1]) and minOf(xs) == some(s[0]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-TYPECLASS-02
test "FP-TYPECLASS-02 Given a sorted sequence, when insertSorted adds a value, then the result is sorted, one longer, has the same elements, and the input is unchanged":
  let outcome = check(pair(ints(), intIn(-20, 20)), proc(p: (seq[int], int)): bool {.raises: [CatchableError].} =
    let s = p[0].sorted
    let before = s
    let r = insertSorted(s, p[1])
    isSorted(r) and r.len == s.len + 1 and r.sorted == (s & @[p[1]]).sorted and s == before)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-TYPECLASS-03
test "FP-TYPECLASS-03 Given any sequence, when isSorted is asked, then it agrees with comparing against the sorted copy":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    isSorted(xs) == (xs == xs.sorted))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-TYPECLASS-04
test "FP-TYPECLASS-04 Given the instances int, string, an object and a distinct type, when the order laws are checked on generated triples, then each holds":
  let intOk = check(seqOf(intIn(-9, 9), 3, 3), proc(t: seq[int]): bool {.raises: [CatchableError].} =
    isTotalOrderOn(t[0], t[1], t[2]))
  checkpoint describe(intOk)
  check intOk.passed
  let strOk = check(seqOf(stringOf("ab", 0, 3), 3, 3), proc(t: seq[string]): bool {.raises: [CatchableError].} =
    isTotalOrderOn(t[0], t[1], t[2]))
  checkpoint describe(strOk)
  check strOk.passed
  let verOk = check(seqOf(versions(), 3, 3), proc(t: seq[Version]): bool {.raises: [CatchableError].} =
    isTotalOrderOn(t[0], t[1], t[2]))
  checkpoint describe(verOk)
  check verOk.passed
  let metOk = check(seqOf(intIn(-9, 9), 3, 3), proc(t: seq[int]): bool {.raises: [CatchableError].} =
    isTotalOrderOn(Meters(t[0]), Meters(t[1]), Meters(t[2])))
  checkpoint describe(metOk)
  check metOk.passed

# SPEC: FP-TYPECLASS-05
test "FP-TYPECLASS-05 Given instances that satisfy the concept but break the laws, when the order laws are checked, then a counterexample is found":
  check isTotalOrderOn(Clock(tick: 0), Clock(tick: 3), Clock(tick: 6)) == false
  check isTotalOrderOn(NaN, 1.0, 2.0) == false
  let outcome = check(seqOf(intIn(0, 9), 3, 3), proc(t: seq[int]): bool {.raises: [CatchableError].} =
    isTotalOrderOn(Clock(tick: t[0]), Clock(tick: t[1]), Clock(tick: t[2])))
  check not outcome.passed

# SPEC: FP-TYPECLASS-06
test "FP-TYPECLASS-06 Given types with and without the operations, when tested against the concept, then only the ones that have them are accepted":
  check int is Orderable
  check string is Orderable
  check Version is Orderable
  check Meters is Orderable
  check Clock is Orderable
  check not (NoOrder is Orderable)
  check not compiles(maxOf(@[NoOrder(a: 1)]))

# SPEC: FP-TYPECLASS-07
test "FP-TYPECLASS-07 Given a polymorphic function that never inspects elements, when it meets map, then backwards commutes with map and is its own inverse":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    backwards(xs.map(inc1)) == backwards(xs).map(inc1) and backwards(backwards(xs)) == xs and
      backwards(xs.mapIt($it)) == backwards(xs).mapIt($it))
  checkpoint describe(outcome)
  check outcome.passed
