## Skew-binary random-access list: a persistent sequence with O(1) `cons`/`head`/`tail` and
## O(log n) indexed `get` and `updated`.
##
## The list is a short spine of complete binary trees whose sizes are of the form 2^k - 1, in
## non-decreasing order with at most the first two equal (a skew-binary number). Consing links the
## first two trees when they have equal size, otherwise starts a new one-element tree; that is why
## no carry ever ripples. Use it when you need a stack that also supports indexing and
## functional update; use `pvector` for append-at-the-end with indexing, `cons_list` when you never index.

import std/options
import nimcs/ds/cons_list

type
  Tree[T] = ref object
    elem: T
    left, right: Tree[T]    ## both nil for a single element
  Entry[T] = object
    weight: int             ## number of elements, 2^k - 1
    tree: Tree[T]
  SkewList*[T] = object
    spine: ConsList[Entry[T]]
    size: int

func emptySkew*[T](): SkewList[T] {.raises: [].} =
  SkewList[T]()

func len*[T](xs: SkewList[T]): int {.raises: [].} =
  xs.size

func isEmpty*[T](xs: SkewList[T]): bool {.raises: [].} =
  xs.size == 0

func cons*[T](xs: SkewList[T]; x: T): SkewList[T] {.raises: [].} =
  let first = xs.spine.head
  let second = xs.spine.tail.head
  if first.isSome and second.isSome and first.get.weight == second.get.weight:
    let w = first.get.weight
    let linked = Entry[T](weight: 1 + 2 * w,
      tree: Tree[T](elem: x, left: first.get.tree, right: second.get.tree))
    SkewList[T](spine: xs.spine.tail.tail.cons(linked), size: xs.size + 1)
  else:
    SkewList[T](spine: xs.spine.cons(Entry[T](weight: 1, tree: Tree[T](elem: x))), size: xs.size + 1)

func head*[T](xs: SkewList[T]): Option[T] {.raises: [].} =
  let first = xs.spine.head
  if first.isNone: none(T) else: some(first.get.tree.elem)

func tail*[T](xs: SkewList[T]): SkewList[T] {.raises: [].} =
  ## The list without its first element; the tail of the empty list is the empty list.
  let first = xs.spine.head
  if first.isNone: xs
  else:
    let e = first.get
    let rest = xs.spine.tail
    if e.weight == 1: SkewList[T](spine: rest, size: xs.size - 1)
    else:
      let half = e.weight div 2
      SkewList[T](spine: rest.cons(Entry[T](weight: half, tree: e.tree.right))
        .cons(Entry[T](weight: half, tree: e.tree.left)), size: xs.size - 1)

func lookupTree[T](w: int; t: Tree[T]; i: int): T =
  ## Requires 0 <= i < w.
  if i == 0: t.elem
  else:
    let half = w div 2
    if i <= half: lookupTree(half, t.left, i - 1)
    else: lookupTree(half, t.right, i - 1 - half)

func updateTree[T](w: int; t: Tree[T]; i: int; x: T): Tree[T] =
  if i == 0: Tree[T](elem: x, left: t.left, right: t.right)
  else:
    let half = w div 2
    if i <= half: Tree[T](elem: t.elem, left: updateTree(half, t.left, i - 1, x), right: t.right)
    else: Tree[T](elem: t.elem, left: t.left, right: updateTree(half, t.right, i - 1 - half, x))

func get*[T](xs: SkewList[T]; i: int): Option[T] {.raises: [].} =
  ## Element at index `i` (0 is the head); none when out of range.
  if i < 0 or i >= xs.size: return none(T)
  var offset = i
  for e in items(xs.spine):
    if offset < e.weight: return some(lookupTree(e.weight, e.tree, offset))
    offset -= e.weight
  none(T)

func updated*[T](xs: SkewList[T]; i: int; x: T): Option[SkewList[T]] {.raises: [].} =
  ## A copy with index `i` replaced; none when out of range. Shares every untouched tree.
  if i < 0 or i >= xs.size: return none(SkewList[T])
  var before: seq[Entry[T]]
  var offset = i
  var cur = xs.spine
  while not cur.isEmpty:
    let e = cur.head.get
    if offset < e.weight:
      var spine = cur.tail.cons(Entry[T](weight: e.weight, tree: updateTree(e.weight, e.tree, offset, x)))
      for j in countdown(before.high, 0):
        spine = spine.cons(before[j])
      return some(SkewList[T](spine: spine, size: xs.size))
    offset -= e.weight
    before.add e
    cur = cur.tail
  none(SkewList[T])

func toSeq*[T](xs: SkewList[T]): seq[T] {.raises: [].} =
  var cur = xs
  while not cur.isEmpty:
    result.add cur.head.get
    cur = cur.tail

func fromSeq*[T](items: openArray[T]): SkewList[T] {.raises: [].} =
  var acc = emptySkew[T]()
  for i in countdown(items.high, 0):
    acc = acc.cons(items[i])
  acc

func weights*[T](xs: SkewList[T]): seq[int] {.raises: [].} =
  ## Sizes of the trees in the spine, front first.
  for e in items(xs.spine):
    result.add e.weight

func invariantsHold*[T](xs: SkewList[T]): bool {.raises: [].} =
  ## Weights are 2^k - 1, non-decreasing, strictly increasing after the first two, and they sum to len.
  let ws = xs.weights
  var total = 0
  for i, w in ws:
    if ((w + 1) and w) != 0: return false
    if i >= 1 and w < ws[i - 1]: return false
    if i >= 2 and w == ws[i - 1]: return false
    total += w
  total == xs.size
