## Insertion sort: grow a sorted prefix by sliding each next element left to its place.
##
## Use it for short inputs (a few dozen elements) or inputs that are already nearly sorted, where
## its O(n) best case beats the O(n log n) sorts; it is also the base case that real library sorts
## switch to for small slices. It is stable. The input is never changed: the result is a new `seq`.

type Less[T] = proc(a, b: T): bool {.noSideEffect, raises: [].}

func insertionSort*[T](xs: openArray[T]; less: Less[T]): seq[T] {.raises: [].} =
  ## Ascending by `less` (a strict weak order: `less(a, b)` means "a must come before b").
  ## Elements that are equal under `less` keep their input order (SORT-INSERT-05).
  var sorted = @xs
  for i in 1 ..< sorted.len:
    let item = sorted[i]
    var j = i
    while j > 0 and less(item, sorted[j - 1]):
      sorted[j] = sorted[j - 1]
      dec j
    sorted[j] = item
  sorted

func insertionSort*[T](xs: openArray[T]): seq[T] {.raises: [].} =
  ## Ascending by `<`.
  insertionSort(xs, proc(a, b: T): bool {.noSideEffect, raises: [].} = a < b)
