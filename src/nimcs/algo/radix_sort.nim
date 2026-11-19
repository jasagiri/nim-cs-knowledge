## Radix sort and counting sort: sort by integer keys without comparing elements.
##
## Use them when keys are non-negative integers (or map to a small range): counting sort is
## O(n + k) for keys below k; LSD radix sort (least significant byte first, one stable counting
## pass per byte) is O(n * bytes). Both are stable and report bad keys as a `Result` error
## instead of guessing. Prefer a comparison sort for arbitrary keys. Inputs are never changed.

import nimcs/fp/result

const maxCountingBound* = 1 shl 24
  ## Largest `bound` that counting sort accepts: it allocates one counter per key value, so a
  ## caller-chosen bound would otherwise decide how much memory the routine takes.

type SortKeyError* = enum
  skNegative    ## a key below zero
  skOutOfRange  ## a key at or above the stated bound
  skBadBound    ## the bound is not positive
  skBoundTooLarge  ## the bound exceeds `maxCountingBound`

func countingSortBy*[T](xs: openArray[T]; bound: int;
    key: proc(x: T): int {.noSideEffect, raises: [].}): Result[seq[T], SortKeyError] {.raises: [].} =
  ## Stable sort by `key(x)`, which must lie in 0 ..< bound (SORT-RADIX-03, SORT-RADIX-04);
  ## a bound above `maxCountingBound` is refused (SORT-RADIX-06).
  if bound < 1:
    return err(seq[T], skBadBound)
  if bound > maxCountingBound:
    return err(seq[T], skBoundTooLarge)
  var counts = newSeq[int](bound + 1)
  for x in xs:
    let k = key(x)
    if k < 0:
      return err(seq[T], skNegative)
    if k >= bound:
      return err(seq[T], skOutOfRange)
    inc counts[k + 1]
  for k in 1 .. bound:
    counts[k] += counts[k - 1]            # counts[k] = number of elements with a smaller key
  var placed = newSeq[T](xs.len)
  for x in xs:
    let k = key(x)
    placed[counts[k]] = x
    inc counts[k]
  ok(placed, SortKeyError)

func countingSort*(xs: openArray[int]; bound: int): Result[seq[int], SortKeyError] {.raises: [].} =
  ## Sorts integers that lie in 0 ..< bound.
  countingSortBy(xs, bound, proc(x: int): int {.noSideEffect, raises: [].} = x)

func radixSort*(xs: openArray[int]): Result[seq[int], SortKeyError] {.raises: [].} =
  ## LSD radix sort, base 256, for non-negative integers (SORT-RADIX-01, SORT-RADIX-02).
  var biggest = 0
  for x in xs:
    if x < 0:
      return err(seq[int], skNegative)
    biggest = max(biggest, x)
  var current = @xs
  var shift = 0
  while shift < 63 and (biggest shr shift) > 0:
    var counts: array[257, int]
    for x in current:
      inc counts[((x shr shift) and 255) + 1]
    for d in 1 .. 256:
      counts[d] += counts[d - 1]
    var next = newSeq[int](current.len)
    for x in current:
      let d = (x shr shift) and 255
      next[counts[d]] = x
      inc counts[d]
    current = next
    shift += 8
  ok(current, SortKeyError)
