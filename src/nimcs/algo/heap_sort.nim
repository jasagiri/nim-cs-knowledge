## Heap sort: build a max-heap in an array, then repeatedly move the largest element to the end.
##
## Use it when you need an O(n log n) worst case with O(1) extra space beyond the result copy and
## do not need stability. It is not stable: equal elements may swap order. The input is never
## changed; the heap lives in a local copy.

type Less[T] = proc(a, b: T): bool {.noSideEffect, raises: [].}

func siftDown[T](heap: var seq[T]; root, size: int; less: Less[T]) {.raises: [].} =
  ## Restores the max-heap property below `root` within heap[0 ..< size].
  var parent = root
  while true:
    let left = 2 * parent + 1
    if left >= size:
      break
    var big = left
    if left + 1 < size and less(heap[left], heap[left + 1]):
      big = left + 1
    if not less(heap[parent], heap[big]):
      break
    swap(heap[parent], heap[big])
    parent = big

func heapSort*[T](xs: openArray[T]; less: Less[T]): seq[T] {.raises: [].} =
  ## Ascending by `less`. Not stable.
  var heap = @xs
  for root in countdown(heap.len div 2 - 1, 0):
    siftDown(heap, root, heap.len, less)
  for last in countdown(heap.len - 1, 1):
    swap(heap[0], heap[last])
    siftDown(heap, 0, last, less)
  heap

func heapSort*[T](xs: openArray[T]): seq[T] {.raises: [].} =
  ## Ascending by `<`.
  heapSort(xs, proc(a, b: T): bool {.noSideEffect, raises: [].} = a < b)
