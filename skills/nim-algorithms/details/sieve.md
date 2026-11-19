# Sieve of Eratosthenes

## Intent
To list the primes up to n, start with every number marked prime and, for each prime p found, cross off its multiples starting at p*p
(smaller multiples were already crossed off by smaller primes). What remains marked is exactly the primes.

## Use when / avoid when
- Use it when many primality answers or the full list of primes up to a known bound are needed.
- Use trial division (`isPrimeTrial`) for a single small number: O(sqrt n) with no table.
- Use a probabilistic primality test for one huge number; the sieve's memory is proportional to n.

## Nim shape
`sieveFlags(limit)` returns `Option[seq[bool]]` indexed by number; `primesUpTo(limit)` returns the ascending list as an `Option`. A limit above `maxSieveLimit` (100 million)
gives `none` instead of a huge allocation; a limit below 2 yields an empty list, which is a complete answer, not a failure. `isPrimeTrial` is the independent reference the sieve is checked against. Module: `src/nimcs/algo/sieve.nim`.

```nim
import std/options
import nimcs/algo/sieve

doAssert primesUpTo(30).get == @[2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
doAssert primesUpTo(100_000).get.len == 9592
doAssert sieveFlags(7).get[7] and not sieveFlags(7).get[6]
doAssert primesUpTo(1).get.len == 0
doAssert primesUpTo(maxSieveLimit + 1).isNone
```

## Laws and invariants
- Flag i is true exactly when trial division calls i prime, for every i up to the limit (NUM-SIEVE-01).
- The prime counts match the prime-counting function: 25 up to 100, 168 up to 1000, 9592 up to 100000 (NUM-SIEVE-02).
- A limit below 2 gives an empty list; any list is strictly ascending, within the limit, and made of primes (NUM-SIEVE-03).
- A limit above `maxSieveLimit` gives `none` (NUM-SIEVE-04).

## Complexity
Time O(n log log n), space O(n) (one flag per number). Trial division: O(sqrt n) per query.

## Pitfalls
Starting the inner loop at 2*p repeats work, and testing `p * p <= limit` with a limit near `high(int)` overflows:

```nim bad
var p = 2
while p * p <= limit:          # p * p can overflow for large limits
  var multiple = 2 * p         # redundant: smaller multiples are already crossed off
```

Fix: test `p <= limit div p` and start at `p * p`, as `sieveFlags` does. Do not size the table as `limit` instead of `limit + 1`: the limit itself must be an index.

## Related
`number_theory.md`, `fib_matrix.md`, `backtracking.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `29ca95172575b79a` Algorithms and Data Structures
- `61811291625a13a9` Algorithms for Competitive Programming
- `c6a234b79d2a7c88` Computer Science II
- `b8cf0456394ed527` Learn Programming with OCaml: Algorithms and Data Structures
- `04a7132319218b7b` Matters Computational: Ideas, Algorithms, Source Code
