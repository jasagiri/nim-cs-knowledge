## Binary search over a sorted sequence, and over any monotone predicate.
##
## Use `partitionPoint` / `firstTrue` for "where does this yes/no question flip?" (the idea behind
## every binary search, including searching an answer rather than an array); use `lowerBound`,
## `upperBound` and `binarySearch` for sorted data. Each halves the candidate range, so a lookup
## costs O(log n) comparisons. The input must be sorted by the same `less` you pass (or `<`);
## nothing checks that, and an unsorted input gives an unspecified index (never an exception).
## `std/algorithm` exports routines with the same names; when a module needs both, write
## `import std/algorithm except lowerBound, upperBound, binarySearch`.

import std/[math, options]

type Less[T] = proc(a, b: T): bool {.noSideEffect, raises: [].}

func midpoint(low, high: int): int {.raises: [].} =
  ## A value in low ..< high (low < high) that cannot overflow, even for the whole `int` range:
  ## `high - low` overflows when low < 0 <= high, but then `low + high` cannot, and rounding
  ## down keeps the result below `high`.
  if low < 0 and high >= 0: floorDiv(low + high, 2)
  else: low + (high - low) div 2

func firstTrue*(lo, hi: int; pred: proc(i: int): bool {.noSideEffect, raises: [].}): int {.raises: [].} =
  ## Smallest `i` in lo ..< hi with `pred(i)`, or `hi` when there is none; any `lo`, `hi` in the `int` range are fine. `pred` must be monotone
  ## on the range: false for a prefix, then true (SEARCH-FIRST-01). An empty range gives `lo`.
  var low = lo
  var high = hi
  while low < high:
    let mid = midpoint(low, high)
    if pred(mid): high = mid
    else: low = mid + 1
  low

func partitionPoint*[T](xs: openArray[T]; pred: proc(x: T): bool {.noSideEffect, raises: [].}): int {.raises: [].} =
  ## Index of the first element for which `pred` holds, `xs.len` when none does. `pred` must be
  ## false on a prefix of `xs` and true on the rest (SEARCH-PARTITION-01).
  var low = 0
  var high = xs.len
  while low < high:
    let mid = low + (high - low) div 2
    if pred(xs[mid]): high = mid
    else: low = mid + 1
  low

func lowerBound*[T](xs: openArray[T]; x: T; less: Less[T]): int {.raises: [].} =
  ## First index whose element is not before `x`: where `x` would be inserted before its equals
  ## (SEARCH-LOWER-01).
  var low = 0
  var high = xs.len
  while low < high:
    let mid = low + (high - low) div 2
    if less(xs[mid], x): low = mid + 1
    else: high = mid
  low

func lowerBound*[T](xs: openArray[T]; x: T): int {.raises: [].} =
  lowerBound(xs, x, proc(a, b: T): bool {.noSideEffect, raises: [].} = a < b)

func upperBound*[T](xs: openArray[T]; x: T; less: Less[T]): int {.raises: [].} =
  ## First index whose element is after `x`: where `x` would be inserted after its equals
  ## (SEARCH-UPPER-01).
  var low = 0
  var high = xs.len
  while low < high:
    let mid = low + (high - low) div 2
    if less(x, xs[mid]): high = mid
    else: low = mid + 1
  low

func upperBound*[T](xs: openArray[T]; x: T): int {.raises: [].} =
  upperBound(xs, x, proc(a, b: T): bool {.noSideEffect, raises: [].} = a < b)

func binarySearch*[T](xs: openArray[T]; x: T; less: Less[T]): Option[int] {.raises: [].} =
  ## Index of the first element equal to `x` (neither before nor after it), or none
  ## (SEARCH-FIND-01).
  let i = lowerBound(xs, x, less)
  if i < xs.len and not less(x, xs[i]): some(i)
  else: none(int)

func binarySearch*[T](xs: openArray[T]; x: T): Option[int] {.raises: [].} =
  binarySearch(xs, x, proc(a, b: T): bool {.noSideEffect, raises: [].} = a < b)
