import std/[unittest, options]
import propcheck
import nimcs/fp/[result, option_ops]

func opts(): Gen[Option[int]] {.raises: [ValueError].} =
  pair(boolean(), intIn(-20, 20)).map(proc(p: (bool, int)): Option[int] {.raises: [].} =
    if p[0]: some(p[1]) else: none(int))

# SPEC: FP-OPTIONOPS-01
test "FP-OPTIONOPS-01 Given an option, when okOr, then some becomes ok and none becomes the given error":
  check some(3).okOr("missing") == ok(3, string)
  check none(int).okOr("missing") == err(int, "missing")
  let outcome = check(opts(), proc(o: Option[int]): bool {.raises: [CatchableError].} =
    o.okOr("m").isOk == o.isSome)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-OPTIONOPS-02
test "FP-OPTIONOPS-02 Given a result, when toOption then okOr back, then a success round-trips":
  check ok(4, string).toOption == some(4)
  check err(int, "bad").toOption == none(int)
  let outcome = check(intIn(-20, 20), proc(x: int): bool {.raises: [CatchableError].} =
    ok(x, string).toOption.okOr("e") == ok(x, string))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-OPTIONOPS-03
test "FP-OPTIONOPS-03 Given options, when orElse, then none is the identity and the left value wins":
  check some(1).orElse(some(2)) == some(1)
  check none(int).orElse(some(2)) == some(2)
  let outcome = check(opts(), proc(a: Option[int]): bool {.raises: [CatchableError].} =
    a.orElse(none(int)) == a and none(int).orElse(a) == a)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-OPTIONOPS-03
test "FP-OPTIONOPS-03 Given three options, when orElse is grouped either way, then the result is the same":
  let outcome = check(pair(opts(), pair(opts(), opts())),
    proc(t: (Option[int], (Option[int], Option[int]))): bool {.raises: [CatchableError].} =
      let (a, (b, c)) = t
      a.orElse(b).orElse(c) == a.orElse(b.orElse(c)))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-OPTIONOPS-04
test "FP-OPTIONOPS-04 Given two options, when both, then it is some of the pair only if both are some":
  check both(some(1), some("a")) == some((1, "a"))
  check both(some(1), none(string)).isNone
  let outcome = check(pair(opts(), opts()), proc(p: (Option[int], Option[int])): bool {.raises: [CatchableError].} =
    both(p[0], p[1]).isSome == (p[0].isSome and p[1].isSome))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-OPTIONOPS-05
test "FP-OPTIONOPS-05 Given a list of options, when sequence, then all present gives the values in order, else none":
  check sequence([some(1), some(2)]) == some(@[1, 2])
  check sequence([some(1), none(int)]).isNone
  check sequence(newSeq[Option[int]]()) == some(newSeq[int]())
  let outcome = check(seqOf(opts(), 0, 8), proc(xs: seq[Option[int]]): bool {.raises: [CatchableError].} =
    let s = sequence(xs)
    var allSome = true
    for x in xs:
      allSome = allSome and x.isSome
    if allSome:
      s.isSome and s.get == catSome(xs)
    else:
      s.isNone)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-OPTIONOPS-06
test "FP-OPTIONOPS-06 Given a list of options, when catSome, then only the present values remain in order":
  check catSome([some(1), none(int), some(3)]) == @[1, 3]
  let outcome = check(seqOf(opts(), 0, 8), proc(xs: seq[Option[int]]): bool {.raises: [CatchableError].} =
    var expected: seq[int]
    for x in xs:
      if x.isSome:
        expected.add x.get
    catSome(xs) == expected)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-OPTIONOPS-07
test "FP-OPTIONOPS-07 Given a list of options, when firstSome, then it is the first present element":
  check firstSome([none(int), some(2), some(3)]) == some(2)
  check firstSome(newSeq[Option[int]]()).isNone
  let outcome = check(seqOf(opts(), 0, 8), proc(xs: seq[Option[int]]): bool {.raises: [CatchableError].} =
    let c = catSome(xs)
    firstSome(xs) == (if c.len > 0: some(c[0]) else: none(int)))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-OPTIONOPS-08
test "FP-OPTIONOPS-08 Given std options, when map and flatMap run on none, then the callback is not needed and none stays none":
  let nothing = none(int)
  check nothing.map(proc(x: int): int = x + 1).isNone
  check nothing.flatMap(proc(x: int): Option[int] = some(x)).isNone
  check some(2).map(proc(x: int): int = x + 1) == some(3)
  check some(2).filter(proc(x: int): bool = x > 5).isNone
  check none(int).get(7) == 7
  check some(1).get(7) == 1

# SPEC: FP-OPTIONOPS-08
test "FP-OPTIONOPS-08 Given any option, when mapped with identity, then it is unchanged":
  let outcome = check(opts(), proc(o: Option[int]): bool {.raises: [CatchableError].} =
    o.map(proc(x: int): int = x) == o)
  checkpoint describe(outcome)
  check outcome.passed
