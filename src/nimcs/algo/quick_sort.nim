## Quick sort, functional form: split around a pivot into smaller, equal and larger parts, sort the
## outer two recursively and concatenate.
##
## Use it to show divide and conquer without in-place index juggling. The three-way split puts
## every element equal to the pivot in the middle part, so inputs with many duplicates do not
## degrade. The pivot is the median of the first, middle and last element, which makes sorted and
## reverse-sorted inputs fast; an adversarial input can still reach O(n^2) time and O(n) recursion
## depth. Prefer `merge_sort` or `heap_sort` when a worst-case bound matters. Each part keeps its
## input order, so this version happens to be stable. The input is never changed.

type Less[T] = proc(a, b: T): bool {.noSideEffect, raises: [].}

func pivotOf[T](xs: openArray[T]; less: Less[T]): T {.raises: [].} =
  ## Median of the first, middle and last element (xs is not empty).
  let a = xs[0]
  let b = xs[xs.len div 2]
  let c = xs[xs.len - 1]
  if less(a, b):
    if less(b, c): b
    elif less(a, c): c
    else: a
  else:
    if less(a, c): a
    elif less(b, c): c
    else: b

func quickSort*[T](xs: openArray[T]; less: Less[T]): seq[T] {.raises: [].} =
  ## Ascending by `less`. Equal elements keep their input order (SORT-QUICK-05).
  if xs.len <= 1:
    return @xs
  let pivot = pivotOf(xs, less)
  var smaller, equal, larger: seq[T]
  for x in xs:
    if less(x, pivot): smaller.add x
    elif less(pivot, x): larger.add x
    else: equal.add x
  quickSort(smaller, less) & equal & quickSort(larger, less)

func quickSort*[T](xs: openArray[T]): seq[T] {.raises: [].} =
  ## Ascending by `<`.
  quickSort(xs, proc(a, b: T): bool {.noSideEffect, raises: [].} = a < b)
