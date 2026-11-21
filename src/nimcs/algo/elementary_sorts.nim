## Selection sort and shellsort: two elementary sorts, and when `insertion_sort` is the better pick.
##
## Selection sort repeatedly picks the smallest remaining element and swaps it into place: always
## about n^2/2 comparisons, but at most n - 1 swaps, so it suits the rare case where writing an
## element is far costlier than comparing. It is NOT stable. Shellsort runs insertion sort over
## elements a gap apart, with shrinking gaps ending at 1, so far-apart elements travel quickly;
## it needs no extra memory and beats insertion sort on mid-sized unsorted input, but it is NOT
## stable either. For short or nearly sorted input, or whenever equal elements must keep their
## order, use `insertion_sort` (stable) or `merge_sort`. Inputs are never changed.

import nimcs/fp/result

type
  Less[T] = proc(a, b: T): bool {.noSideEffect, raises: [].}

  GapError* = enum
    gapNone          ## no gap at all
    gapNotPositive   ## a gap below one
    gapNotDescending ## a gap not smaller than the one before it
    gapNoFinalOne    ## the last gap is not 1, so the final pass would not finish the sort

func selectionPass[T](xs: openArray[T]; less: Less[T]): tuple[sorted: seq[T], swaps: int] =
  ## The whole sort, also counting swaps. Among equal minima the leftmost is picked.
  var a = @xs
  for i in 0 ..< max(0, a.len - 1):
    var smallest = i
    for j in i + 1 ..< a.len:
      if less(a[j], a[smallest]):
        smallest = j
    if smallest != i:
      swap(a[i], a[smallest])
      inc result.swaps
  result.sorted = a

func selectionSort*[T](xs: openArray[T]; less: Less[T]): seq[T] {.raises: [].} =
  ## Ascending by `less`. Not stable: the long-distance swap can carry an element past an equal one
  ## (ELEMSORT-SELECT-04).
  selectionPass(xs, less).sorted

func selectionSort*[T](xs: openArray[T]): seq[T] {.raises: [].} =
  ## Ascending by `<`.
  selectionSort(xs, proc(a, b: T): bool {.noSideEffect, raises: [].} = a < b)

func selectionSwaps*[T](xs: openArray[T]; less: Less[T]): int {.raises: [].} =
  ## How many swaps selection sort makes on `xs`: at most len - 1 (ELEMSORT-SELECT-03).
  selectionPass(xs, less).swaps

func shellGaps*(n: int): seq[int] {.raises: [].} =
  ## Knuth's gap sequence 1, 4, 13, 40, ... (each 3h + 1), the terms below n div 3, largest
  ## first, always ending in 1 (ELEMSORT-SHELL-04). `[1]` for n <= 3 and for n <= 0.
  var up = @[1]
  var h = 1
  while 3 * h + 1 < n div 3:
    h = 3 * h + 1
    up.add h
  for i in countdown(up.high, 0):
    result.add up[i]

func gapSorted[T](xs: openArray[T]; gaps: openArray[int]; less: Less[T]): seq[T] =
  var a = @xs
  for gap in gaps:
    for i in gap ..< a.len:
      let item = a[i]
      var j = i
      while j >= gap and less(item, a[j - gap]):
        a[j] = a[j - gap]
        j -= gap
      a[j] = item
  a

func shellSortWithGaps*[T](xs: openArray[T]; gaps: openArray[int];
    less: Less[T]): Result[seq[T], GapError] {.raises: [].} =
  ## Shellsort with the given gaps, which must be strictly descending, positive and end in 1
  ## (ELEMSORT-SHELL-05). The sort is correct for any such sequence (ELEMSORT-SHELL-02); only the
  ## speed depends on it. Not stable (ELEMSORT-SHELL-03).
  if gaps.len == 0:
    return err(seq[T], gapNone)
  for i, gap in gaps:
    if gap < 1:
      return err(seq[T], gapNotPositive)
    if i > 0 and gap >= gaps[i - 1]:
      return err(seq[T], gapNotDescending)
  if gaps[gaps.high] != 1:
    return err(seq[T], gapNoFinalOne)
  ok(gapSorted(xs, gaps, less), GapError)

func shellSort*[T](xs: openArray[T]; less: Less[T]): seq[T] {.raises: [].} =
  ## Ascending by `less`, with Knuth's gaps (ELEMSORT-SHELL-01). Not stable (ELEMSORT-SHELL-03).
  gapSorted(xs, shellGaps(xs.len), less)

func shellSort*[T](xs: openArray[T]): seq[T] {.raises: [].} =
  ## Ascending by `<`.
  shellSort(xs, proc(a, b: T): bool {.noSideEffect, raises: [].} = a < b)
