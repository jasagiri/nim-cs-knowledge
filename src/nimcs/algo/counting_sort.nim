## Counting sort over a stated key range lo .. hi, negative keys included.
##
## Use it to sort integers, or records by an integer key, when the range of keys is small next to
## the number of items (grades, ages, byte values, days of a year): it counts how many items have
## each key, turns the counts into start positions by a running sum, and places each item at its
## key's next free position, in O(n + range) with no comparisons. Placing items in input order
## makes it stable, which is what lets `radix_sort` run one counting pass per digit. The range is
## stated by the caller (or found by `countingSortAuto`) and capped, because it decides how much
## memory is allocated. For keys that start at zero, `radix_sort.nim` offers the same routine
## with a bound instead of a range. Inputs are never changed.

import std/options
import nimcs/fp/result

const maxCountingSpan* = 1 shl 24
  ## The most distinct key values (hi - lo + 1) that a counting sort here will allocate counters for.

type
  CountingError* = enum
    ceBadRange        ## lo is above hi
    ceRangeTooLarge   ## the range holds more than `maxCountingSpan` values
    ceOutOfRange      ## a key outside lo .. hi

func spanTooLarge(lo, hi: int): bool =
  ## hi - lo + 1 > maxCountingSpan without overflowing, for lo <= hi.
  if lo < 0 and hi >= 0:
    hi >= maxCountingSpan + lo     # hi - lo >= maxCountingSpan, rearranged so nothing overflows
  else:
    hi - lo >= maxCountingSpan     # both on one side of zero: the difference fits

func checkRange(lo, hi: int): Option[CountingError] =
  if lo > hi: some(ceBadRange)
  elif spanTooLarge(lo, hi): some(ceRangeTooLarge)
  else: none(CountingError)

func keyHistogram*(keys: openArray[int]; lo, hi: int): Result[seq[int], CountingError] {.raises: [].} =
  ## How many of `keys` equal each value of lo .. hi: entry i counts the keys equal to lo + i
  ## (SORT-COUNTING-05). The first step of the sort, useful on its own for frequency tables.
  let bad = checkRange(lo, hi)
  if bad.isSome:
    return err(seq[int], bad.get)
  var counts = newSeq[int](hi - lo + 1)
  for k in keys:
    if k < lo or k > hi:
      return err(seq[int], ceOutOfRange)
    inc counts[k - lo]
  ok(counts, CountingError)

func countingSortByRange*[T](xs: openArray[T]; lo, hi: int;
    key: proc(x: T): int {.noSideEffect, raises: [].}): Result[seq[T], CountingError] {.raises: [].} =
  ## Sorts by `key(x)`, which must lie in lo .. hi, keeping the input order of items with equal
  ## keys (SORT-COUNTING-02). Fails on a bad or oversized range and on a key outside it
  ## (SORT-COUNTING-03, SORT-COUNTING-04).
  let bad = checkRange(lo, hi)
  if bad.isSome:
    return err(seq[T], bad.get)
  var next = newSeq[int](hi - lo + 2)        # next[k - lo + 1] counts key k, then becomes its start
  for x in xs:
    let k = key(x)
    if k < lo or k > hi:
      return err(seq[T], ceOutOfRange)
    inc next[k - lo + 1]
  for i in 1 ..< next.len:
    next[i] += next[i - 1]                   # next[i] = number of items with a smaller key than lo + i
  var placed = newSeq[T](xs.len)
  for x in xs:
    let slot = key(x) - lo
    placed[next[slot]] = x
    inc next[slot]
  ok(placed, CountingError)

func countingSortRange*(xs: openArray[int]; lo, hi: int): Result[seq[int], CountingError] {.raises: [].} =
  ## Sorts integers that lie in lo .. hi (SORT-COUNTING-01); idempotent (SORT-COUNTING-07).
  countingSortByRange(xs, lo, hi, proc(x: int): int {.noSideEffect, raises: [].} = x)

func countingSortAuto*(xs: openArray[int]): Result[seq[int], CountingError] {.raises: [].} =
  ## Sorts any integers whose smallest and largest values are less than `maxCountingSpan` apart,
  ## finding the range itself (SORT-COUNTING-06). The empty input gives an empty result.
  if xs.len == 0:
    return ok(newSeq[int](), CountingError)
  var lo = xs[0]
  var hi = xs[0]
  for x in xs:
    lo = min(lo, x)
    hi = max(hi, x)
  countingSortRange(xs, lo, hi)
