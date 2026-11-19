## Sieve of Eratosthenes: all primes up to a limit by crossing off the multiples of each prime.
##
## Use it when many primality answers are needed below a known bound: O(n log log n) time and
## O(n) space for every prime up to n, against O(sqrt n) per query for trial division
## (`isPrimeTrial`). For a single huge number use a probabilistic test instead of either.
## A limit below 2 has no primes, so the answer is simply empty.

import std/options

const maxSieveLimit*: int = 100_000_000
  ## Largest limit accepted; the flag table has `limit + 1` bytes.

func sieveFlags*(limit: int): Option[seq[bool]] {.raises: [].} =
  ## `result[i]` is true exactly when `i` is prime, for 0 <= i <= limit (NUM-SIEVE-01). The table is
  ## empty when `limit` is negative; none when `limit` exceeds `maxSieveLimit` (NUM-SIEVE-04).
  if limit > maxSieveLimit:
    return none(seq[bool])
  if limit < 0:
    return some(newSeq[bool]())
  var flags = newSeq[bool](limit + 1)
  for i in 2 .. limit:
    flags[i] = true
  var p = 2
  while p <= limit div p:
    if flags[p]:
      var multiple = p * p
      while multiple <= limit:
        flags[multiple] = false
        multiple += p
    inc p
  some(flags)

func primesUpTo*(limit: int): Option[seq[int]] {.raises: [].} =
  ## All primes <= `limit`, ascending (NUM-SIEVE-02, NUM-SIEVE-03); none beyond `maxSieveLimit`.
  let flags = sieveFlags(limit)
  if flags.isNone:
    return none(seq[int])
  var primes: seq[int] = @[]
  for i in 0 ..< flags.get.len:
    if flags.get[i]:
      primes.add i
  some(primes)

func isPrimeTrial*(n: int): bool {.raises: [].} =
  ## Primality by trial division up to the square root; the reference the sieve is checked
  ## against (NUM-SIEVE-01).
  if n < 2:
    return false
  var d = 2
  while d <= n div d:
    if n mod d == 0:
      return false
    inc d
  true
