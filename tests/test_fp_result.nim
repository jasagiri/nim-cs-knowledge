import std/unittest
import propcheck
import nimcs/fp/result

type R = Result[int, string]

func mk(flag: bool; n: int): R {.raises: [].} =
  if flag: ok(n, string) else: err(int, "e" & $n)

func inc1(x: int): int {.raises: [].} = x + 1
func dbl(x: int): int {.raises: [].} = x * 2
func ident(x: int): int {.raises: [].} = x
func halve(x: int): R {.raises: [].} =
  if x mod 2 == 0: ok(x div 2, string) else: err(int, "odd")
func nonNeg(x: int): R {.raises: [].} =
  if x >= 0: ok(x, string) else: err(int, "negative")

func results(): Gen[R] {.raises: [ValueError].} =
  pair(boolean(), intIn(-50, 50)).map(proc(p: (bool, int)): R {.raises: [].} = mk(p[0], p[1]))

# SPEC: FP-RESULT-01
test "FP-RESULT-01 Given any result, when mapped with identity, then it is unchanged":
  let outcome = check(results(), proc(r: R): bool {.raises: [CatchableError].} =
    r.map(ident) == r)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-RESULT-01
test "FP-RESULT-01 Given any result, when mapped twice, then it equals one map of the composition":
  let outcome = check(results(), proc(r: R): bool {.raises: [CatchableError].} =
    r.map(inc1).map(dbl) == r.map(proc(x: int): int {.noSideEffect, raises: [].} = dbl(inc1(x))))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-RESULT-02
test "FP-RESULT-02 Given an error at the start, when flatMapped, then the error is kept and no value is produced":
  let start = err(int, "boom")
  let after = start.flatMap(halve).flatMap(nonNeg)
  check after.isErr
  check after.error == "boom"

# SPEC: FP-RESULT-02
test "FP-RESULT-02 Given a chain, when the first step fails, then the reported error is the first one":
  let after = ok(3, string).flatMap(halve).flatMap(nonNeg)
  check after.error == "odd"
  let later = ok(-4, string).flatMap(halve).flatMap(nonNeg)
  check later.error == "negative"

# SPEC: FP-RESULT-03
test "FP-RESULT-03 Given any result, when flatMapped with ok, then it is unchanged (right identity)":
  let outcome = check(results(), proc(r: R): bool {.raises: [CatchableError].} =
    r.flatMap(proc(x: int): R {.noSideEffect, raises: [].} = ok(x, string)) == r)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-RESULT-03
test "FP-RESULT-03 Given a value, when ok(x).flatMap(f), then it equals f(x) (left identity)":
  let outcome = check(intIn(-50, 50), proc(x: int): bool {.raises: [CatchableError].} =
    ok(x, string).flatMap(halve) == halve(x))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-RESULT-03
test "FP-RESULT-03 Given any result, when flatMapped in two steps or one composed step, then they agree (associativity)":
  let outcome = check(results(), proc(r: R): bool {.raises: [CatchableError].} =
    r.flatMap(halve).flatMap(nonNeg) ==
      r.flatMap(proc(x: int): R {.noSideEffect, raises: [].} = halve(x).flatMap(nonNeg)))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-RESULT-04
test "FP-RESULT-04 Given an error, when mapErr, then the value side is untouched and the error is changed":
  let r = err(int, "x").mapErr(proc(e: string): int {.noSideEffect, raises: [].} = e.len)
  check r.isErr
  check r.error == 1
  let good = ok(5, string).mapErr(proc(e: string): int {.noSideEffect, raises: [].} = e.len)
  check good.isOk
  check good.value == 5

# SPEC: FP-RESULT-05
test "FP-RESULT-05 Given a result, when valueOr, then ok gives its value and err gives the fallback":
  check ok(7, string).valueOr(0) == 7
  check err(int, "x").valueOr(-1) == -1

# SPEC: FP-RESULT-06
test "FP-RESULT-06 Given results, when compared, then equality looks at the case, value and error":
  check ok(1, string) == ok(1, string)
  check ok(1, string) != ok(2, string)
  check err(int, "a") == err(int, "a")
  check err(int, "a") != err(int, "b")
  check ok(1, string) != err(int, "1")
