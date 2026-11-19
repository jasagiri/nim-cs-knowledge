import std/[unittest, options]
import propcheck
import nimcs/algo/sieve

# SPEC: NUM-SIEVE-01
test "NUM-SIEVE-01 Given any limit, when sieving, then flag i is true exactly when trial division says i is prime":
  let outcome = check(intIn(-3, 400), proc(limit: int): bool {.raises: [CatchableError].} =
    let flags = sieveFlags(limit).get
    var ok = flags.len == (if limit < 0: 0 else: limit + 1)
    for i in 0 ..< flags.len:
      ok = ok and flags[i] == isPrimeTrial(i)
    ok)
  checkpoint describe(outcome)
  check outcome.passed
  check sieveFlags(10).get == @[false, false, true, true, false, true, false, true, false, false, false]

# SPEC: NUM-SIEVE-02
test "NUM-SIEVE-02 Given known limits, when listing primes, then the counts match the prime-counting function":
  check primesUpTo(30).get == @[2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
  check primesUpTo(100).get.len == 25
  check primesUpTo(1000).get.len == 168
  check primesUpTo(100_000).get.len == 9592

# SPEC: NUM-SIEVE-03
test "NUM-SIEVE-03 Given a limit below 2, when listing primes, then the list is empty; any list is strictly ascending":
  check primesUpTo(1).get == newSeq[int]()
  check primesUpTo(0).get == newSeq[int]()
  check primesUpTo(-10).get == newSeq[int]()
  check primesUpTo(2).get == @[2]
  let outcome = check(intIn(0, 500), proc(limit: int): bool {.raises: [CatchableError].} =
    let ps = primesUpTo(limit).get
    var ok = true
    for i in 1 ..< ps.len:
      ok = ok and ps[i - 1] < ps[i]
    for p in ps:
      ok = ok and p <= limit and isPrimeTrial(p)
    ok and primesUpTo(limit).get == ps)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: NUM-SIEVE-04
test "NUM-SIEVE-04 Given a limit above maxSieveLimit, when sieving, then the result is none instead of an allocation":
  check sieveFlags(maxSieveLimit + 1).isNone
  check sieveFlags(high(int)).isNone
  check primesUpTo(high(int)).isNone
  check primesUpTo(low(int)).get.len == 0
  check sieveFlags(1_000_000).isSome   # inside the bound
