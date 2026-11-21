import std/[unittest, options, sequtils]
import propcheck
import nimcs/fp/[result, compose, lazy_stream, functor_monad]

type Res = Result[int, string]

func inc1(x: int): int {.raises: [].} = x + 1
func dbl(x: int): int {.raises: [].} = x * 2
func add2(x, y: int): int {.raises: [].} = x * 10 + y

func halfOpt(x: int): Option[int] {.raises: [].} =
  if x mod 2 == 0: some(x div 2) else: none(int)
func shiftOpt(x: int): Option[int] {.raises: [].} =
  if x > 12: none(int) else: some(x + 3)

func halfRes(x: int): Res {.raises: [].} =
  if x mod 2 == 0: ok(x div 2, string) else: err(int, "odd")
func shiftRes(x: int): Res {.raises: [].} =
  if x > 12: err(int, "big") else: ok(x + 3, string)

func twins(x: int): seq[int] {.raises: [].} = @[x, x + 1]
func evensOnly(x: int): seq[int] {.raises: [].} = (if x mod 2 == 0: @[x] else: newSeq[int]())

func bumpTwice[C](x: C): C {.raises: [].} =
  mixin map
  x.map(inc1).map(inc1)

func opts(): Gen[Option[int]] {.raises: [ValueError].} =
  pair(boolean(), intIn(-20, 20)).map(proc(p: (bool, int)): Option[int] {.raises: [].} =
    if p[0]: some(p[1]) else: none(int))

func ress(): Gen[Res] {.raises: [ValueError].} =
  pair(boolean(), intIn(-20, 20)).map(proc(p: (bool, int)): Res {.raises: [].} =
    if p[0]: ok(p[1], string) else: err(int, "e" & $p[1]))

func ints(): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(-20, 20), 0, 6)

let incFn: Fn[int, int] = inc1
let dblFn: Fn[int, int] = dbl

# SPEC: FP-FUNCTORMONAD-01
test "FP-FUNCTORMONAD-01 Given Option, Result, seq and Stream, when mapped with identity and with two functions in turn, then the functor laws hold":
  let outcome = check(pair(opts(), pair(ress(), ints())),
    proc(t: (Option[int], (Res, seq[int]))): bool {.raises: [CatchableError].} =
      let (o, (r, xs)) = t
      let optOk = o.map(identity[int]) == o and o.map(dbl).map(inc1) == o.map(compose(inc1, dbl))
      let resOk = r.map(identity[int]) == r and r.map(dbl).map(inc1) == r.map(compose(inc1, dbl))
      let seqOk = xs.map(identity[int]) == xs and xs.map(dbl).map(inc1) == xs.map(compose(inc1, dbl))
      let s = fromSeq(xs)
      let streamOk = s.map(identity[int]).toSeq(10) == xs and
        s.map(dbl).map(inc1).toSeq(10) == s.map(compose(inc1, dbl)).toSeq(10)
      optOk and resOk and seqOk and streamOk)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-FUNCTORMONAD-02
test "FP-FUNCTORMONAD-02 Given an option or result, when apply is used with a wrapped identity, then the value is unchanged":
  let idFn: Fn[int, int] = identity[int]
  let outcome = check(pair(opts(), ress()), proc(p: (Option[int], Res)): bool {.raises: [CatchableError].} =
    some(idFn).ap(p[0]) == p[0] and ok(idFn, string).ap(p[1]) == p[1])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-FUNCTORMONAD-03
test "FP-FUNCTORMONAD-03 Given a function and a value, when both are wrapped and applied, then it equals wrapping the application, and interchange holds":
  let outcome = check(intIn(-20, 20), proc(x: int): bool {.raises: [CatchableError].} =
    let homo = some(dblFn).ap(some(x)) == some(dbl(x)) and
      ok(dblFn, string).ap(ok(x, string)) == ok(dbl(x), string)
    # interchange: u <*> pure y == pure ($ y) <*> u
    let applyAt: proc(f: Fn[int, int]): int {.noSideEffect, raises: [].} =
      proc(f: Fn[int, int]): int {.noSideEffect, raises: [].} = f(x)
    let u = some(incFn)
    let inter = u.ap(some(x)) == some(applyAt).ap(u)
    homo and inter)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-FUNCTORMONAD-04
test "FP-FUNCTORMONAD-04 Given wrapped values, when apply is compared with flatMap-then-map, then they agree":
  let outcome = check(pair(opts(), ress()), proc(p: (Option[int], Res)): bool {.raises: [CatchableError].} =
    let (o, r) = p
    let viaOpt = some(dblFn).ap(o) == o.flatMap(proc(x: int): Option[int] = some(dbl(x)))
    let viaRes = ok(dblFn, string).ap(r) == r.flatMap(proc(x: int): Res {.noSideEffect, raises: [].} = ok(dbl(x), string))
    viaOpt and viaRes)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-FUNCTORMONAD-05
test "FP-FUNCTORMONAD-05 Given Option, when flatMap is used with some, then left identity, right identity and associativity hold":
  let outcome = check(pair(opts(), intIn(-20, 20)), proc(p: (Option[int], int)): bool {.raises: [CatchableError].} =
    let (o, x) = p
    some(x).flatMap(halfOpt) == halfOpt(x) and
      o.flatMap(proc(v: int): Option[int] = some(v)) == o and
      o.flatMap(halfOpt).flatMap(shiftOpt) ==
        o.flatMap(proc(v: int): Option[int] = halfOpt(v).flatMap(shiftOpt)))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-FUNCTORMONAD-06
test "FP-FUNCTORMONAD-06 Given seq, when flatMap is used with a singleton list, then the list monad laws hold":
  check @[1, 2].flatMap(twins) == @[1, 2, 2, 3]
  let outcome = check(pair(ints(), intIn(-20, 20)), proc(p: (seq[int], int)): bool {.raises: [CatchableError].} =
    let (xs, x) = p
    @[x].flatMap(twins) == twins(x) and
      xs.flatMap(proc(v: int): seq[int] = @[v]) == xs and
      xs.flatMap(twins).flatMap(evensOnly) ==
        xs.flatMap(proc(v: int): seq[int] = twins(v).flatMap(evensOnly)))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-FUNCTORMONAD-07
test "FP-FUNCTORMONAD-07 Given failing inputs, when apply or map2 combine them, then none or the first error from the left wins":
  check some(incFn).ap(none(int)).isNone
  check none(Fn[int, int]).ap(some(1)).isNone
  check map2(none(int), some(1), add2).isNone
  let badF = err(Fn[int, int], "f failed")
  check badF.ap(err(int, "x failed")) == err(int, "f failed")
  check ok(incFn, string).ap(err(int, "x failed")) == err(int, "x failed")
  check map2(err(int, "a"), err(int, "b"), add2) == err(int, "a")
  check map2(ok(1, string), err(int, "b"), add2) == err(int, "b")
  check map2(ok(1, string), ok(2, string), add2) == ok(12, string)

# SPEC: FP-FUNCTORMONAD-08
test "FP-FUNCTORMONAD-08 Given two options or results, when map2 is used, then it equals mapping a curried function and applying":
  let outcome = check(pair(opts(), opts()), proc(p: (Option[int], Option[int])): bool {.raises: [CatchableError].} =
    let (a, b) = p
    let curried = proc(x: int): Fn[int, int] {.noSideEffect, raises: [].} =
      proc(y: int): int {.noSideEffect, raises: [].} = add2(x, y)
    map2(a, b, add2) == a.map(curried).ap(b))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-FUNCTORMONAD-09
test "FP-FUNCTORMONAD-09 Given lists of functions and values, when apply is used, then every pair is combined with functions outermost":
  check @[incFn, dblFn].ap(@[1, 2]) == @[2, 3, 2, 4]
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let fs = @[incFn, dblFn]
    let applied = fs.ap(xs)
    applied.len == fs.len * xs.len and applied == xs.map(inc1) & xs.map(dbl))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-FUNCTORMONAD-10
test "FP-FUNCTORMONAD-10 Given a generic written against map, when instantiated, then it works for each type with a map and the shape is not a type":
  check bumpTwice(some(1)) == some(3)
  check bumpTwice(ok(1, string)) == ok(3, string)
  check bumpTwice(@[1, 2]) == @[3, 4]
  check bumpTwice(fromSeq([1, 2])).toSeq(5) == @[3, 4]
  check not compiles(bumpTwice(5))
  # A type parameter that itself takes type arguments is not part of the language.
  check not compiles(block:
    func hk[F, A](x: F[A]): F[A] = x
    discard 1)
