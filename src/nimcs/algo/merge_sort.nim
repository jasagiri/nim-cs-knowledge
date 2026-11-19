## Merge sort: sort runs of width 1, 2, 4, ... by merging neighbouring sorted runs.
##
## Use it when you need a stable O(n log n) sort with a guaranteed worst case and can afford O(n)
## extra space. This version is bottom-up (no recursion, so no stack depth to worry about) and
## ping-pongs between two buffers. The input is never changed.

type Less[T] = proc(a, b: T): bool {.noSideEffect, raises: [].}

func mergeRuns[T](src: seq[T]; dst: var seq[T]; lo, mid, hi: int; less: Less[T]) {.raises: [].} =
  ## Merges the sorted runs src[lo ..< mid] and src[mid ..< hi] into dst[lo ..< hi].
  ## Takes from the right run only when it is strictly smaller, which is what keeps the sort stable.
  var i = lo
  var j = mid
  var k = lo
  while i < mid and j < hi:
    if less(src[j], src[i]):
      dst[k] = src[j]
      inc j
    else:
      dst[k] = src[i]
      inc i
    inc k
  while i < mid:
    dst[k] = src[i]
    inc i
    inc k
  while j < hi:
    dst[k] = src[j]
    inc j
    inc k

func mergeSort*[T](xs: openArray[T]; less: Less[T]): seq[T] {.raises: [].} =
  ## Ascending by `less`, stable: equal elements keep their input order (SORT-MERGE-05).
  var src = @xs
  var dst = @xs
  var width = 1
  while width < src.len:
    var lo = 0
    while lo < src.len:
      let mid = min(lo + width, src.len)
      let hi = min(lo + 2 * width, src.len)
      mergeRuns(src, dst, lo, mid, hi, less)
      lo += 2 * width
    swap(src, dst)
    width *= 2
  src

func mergeSort*[T](xs: openArray[T]): seq[T] {.raises: [].} =
  ## Ascending by `<`.
  mergeSort(xs, proc(a, b: T): bool {.noSideEffect, raises: [].} = a < b)
