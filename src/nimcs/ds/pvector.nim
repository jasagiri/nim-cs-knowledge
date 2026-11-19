## Persistent vector: a 32-way trie giving O(log32 n) indexed `get`, `updated` and `push`.
##
## Elements live in leaves of up to 32 items; interior nodes hold up to 32 children; the index is
## read five bits at a time from the top. An update copies the one path from the root to the
## leaf (at most 7 nodes for 2^32 elements) and shares everything else, so the old vector stays
## valid. Use it for large indexed collections that are updated functionally; use `skew_list`
## when you push and pop at the front. The tail optimisation that real implementations add (an
## unshared buffer at the end) is left out so the shape stays easy to read.

import std/options

const
  bits = 5
  width = 1 shl bits
  mask = width - 1

type
  Node[T] = ref object
    items: seq[T]            ## filled in leaves only
    kids: seq[Node[T]]       ## filled in interior nodes only
  PVector*[T] = object
    root: Node[T]
    shift: int               ## 0 when the root is a leaf, else 5 * (levels above the leaves)
    size: int

func emptyVector*[T](): PVector[T] {.raises: [].} =
  PVector[T](root: Node[T]())

func len*[T](v: PVector[T]): int {.raises: [].} =
  v.size

func isEmpty*[T](v: PVector[T]): bool {.raises: [].} =
  v.size == 0

func capacity[T](v: PVector[T]): int =
  1 shl (v.shift + bits)

func newPath[T](level: int; x: T): Node[T] =
  ## A chain of nodes from `level` down to a leaf holding only `x`.
  if level == 0: Node[T](items: @[x])
  else: Node[T](kids: @[newPath(level - bits, x)])

func pushInto[T](n: Node[T]; level, index: int; x: T): Node[T] =
  if level == 0:
    Node[T](items: n.items & @[x])
  else:
    let slot = (index shr level) and mask
    if slot < n.kids.len:
      var kids = n.kids
      kids[slot] = pushInto(n.kids[slot], level - bits, index, x)
      Node[T](kids: kids)
    else:
      Node[T](kids: n.kids & @[newPath(level - bits, x)])

func push*[T](v: PVector[T]; x: T): PVector[T] {.raises: [].} =
  ## Appends `x` at index `len`.
  let base = if v.root.isNil: emptyVector[T]() else: v
  if base.size == base.capacity:
    PVector[T](root: Node[T](kids: @[base.root, newPath(base.shift, x)]),
      shift: base.shift + bits, size: base.size + 1)
  else:
    PVector[T](root: pushInto(base.root, base.shift, base.size, x), shift: base.shift,
      size: base.size + 1)

func get*[T](v: PVector[T]; i: int): Option[T] {.raises: [].} =
  if i < 0 or i >= v.size: return none(T)
  var n = v.root
  var level = v.shift
  while level > 0:
    n = n.kids[(i shr level) and mask]
    level -= bits
  some(n.items[i and mask])

func setInto[T](n: Node[T]; level, i: int; x: T): Node[T] =
  if level == 0:
    var items = n.items
    items[i and mask] = x
    Node[T](items: items)
  else:
    var kids = n.kids
    let slot = (i shr level) and mask
    kids[slot] = setInto(n.kids[slot], level - bits, i, x)
    Node[T](kids: kids)

func updated*[T](v: PVector[T]; i: int; x: T): Option[PVector[T]] {.raises: [].} =
  ## A copy with index `i` replaced; none when out of range.
  if i < 0 or i >= v.size: none(PVector[T])
  else: some(PVector[T](root: setInto(v.root, v.shift, i, x), shift: v.shift, size: v.size))

func toSeq*[T](v: PVector[T]): seq[T] {.raises: [].} =
  for i in 0 ..< v.size:
    result.add v.get(i).get

func fromSeq*[T](items: openArray[T]): PVector[T] {.raises: [].} =
  var v = emptyVector[T]()
  for x in items:
    v = v.push(x)
  v

func depth*[T](v: PVector[T]): int {.raises: [].} =
  ## Number of nodes on a root-to-leaf path.
  v.shift div bits + 1
