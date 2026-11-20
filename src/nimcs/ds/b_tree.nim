## B-tree: a persistent ordered set whose nodes hold many keys.
##
## Every node stores between `t - 1` and `2t - 1` sorted keys (`t` is the minimum degree; the root
## may hold fewer), an internal node has one more child than keys, and all leaves are at the same
## depth. A search therefore reads O(log_t n) nodes, and each node is a contiguous run of keys:
## that is what pays off when a node is a disk page or a few cache lines. Insertion splits a
## node that grows past `2t - 1` keys and pushes the median up; only the nodes on one
## root-to-leaf path are copied, so the old tree stays valid. The set is insert-only here
## (deletion needs borrow and merge cases that add length without adding a new idea); use
## `rb_tree` for a binary balanced set, `std/sets` when order does not matter.

import std/options

type
  Node[T] = ref object
    ## Immutable once built. `kids` is empty in a leaf, otherwise `keys.len + 1` long.
    keys: seq[T]
    kids: seq[Node[T]]
  BTree*[T] = object
    degree: int
    root: Node[T]
    size: int
  Grown[T] = object
    ## What inserting into a subtree produced: one node, or two nodes and the key between them.
    case split: bool
    of false:
      node: Node[T]
    of true:
      left, right: Node[T]
      mid: T

func newBTree*[T](minDegree: int): Option[BTree[T]] {.raises: [].} =
  ## An empty tree; none when `minDegree` is below 2 (degree 1 would allow empty nodes).
  if minDegree < 2: none(BTree[T])
  else: some(BTree[T](degree: minDegree))

func minDegree*[T](t: BTree[T]): int {.raises: [].} =
  t.degree

func len*[T](t: BTree[T]): int {.raises: [].} =
  t.size

func isEmpty*[T](t: BTree[T]): bool {.raises: [].} =
  t.size == 0

func slot[T](keys: seq[T]; x: T): int =
  ## Number of keys that are smaller than `x` (binary search).
  var lo = 0
  var hi = keys.len
  while lo < hi:
    let mid = (lo + hi) div 2
    if keys[mid] < x: lo = mid + 1
    else: hi = mid
  lo

func isKeyAt[T](keys: seq[T]; i: int; x: T): bool =
  ## True when `keys[i]` exists and equals `x` (equality from `<` only).
  i < keys.len and not (x < keys[i])

func containsNode[T](n: Node[T]; x: T): bool =
  var cur = n
  while not cur.isNil:
    let i = slot(cur.keys, x)
    if isKeyAt(cur.keys, i, x): return true
    cur = if cur.kids.len == 0: nil else: cur.kids[i]
  false

func contains*[T](t: BTree[T]; x: T): bool {.raises: [].} =
  containsNode(t.root, x)

func settle[T](keys: seq[T]; kids: seq[Node[T]]; degree: int): Grown[T] =
  ## A node from `keys` and `kids`, split at the median when it holds more than 2t - 1 keys.
  if keys.len <= 2 * degree - 1:
    Grown[T](split: false, node: Node[T](keys: keys, kids: kids))
  else:
    let m = degree - 1
    let leftKids = if kids.len == 0: newSeq[Node[T]]() else: kids[0 .. m]
    let rightKids = if kids.len == 0: newSeq[Node[T]]() else: kids[m + 1 .. ^1]
    Grown[T](split: true,
      left: Node[T](keys: keys[0 ..< m], kids: leftKids),
      mid: keys[m],
      right: Node[T](keys: keys[m + 1 .. ^1], kids: rightKids))

func insertNode[T](n: Node[T]; x: T; degree: int): Grown[T] =
  ## `x` is known to be absent from the subtree.
  let i = slot(n.keys, x)
  if n.kids.len == 0:
    var keys = n.keys
    keys.insert(x, i)
    settle(keys, n.kids, degree)
  else:
    let g = insertNode(n.kids[i], x, degree)
    var keys = n.keys
    var kids = n.kids
    if g.split:
      keys.insert(g.mid, i)
      kids[i] = g.left
      kids.insert(g.right, i + 1)
    else:
      kids[i] = g.node
    settle(keys, kids, degree)

func insert*[T](t: BTree[T]; x: T): BTree[T] {.raises: [].} =
  ## The tree with `x` added; the same tree when `x` is already a member (idempotent).
  if t.contains(x): return t
  if t.root.isNil:
    return BTree[T](degree: t.degree, root: Node[T](keys: @[x]), size: 1)
  let g = insertNode(t.root, x, t.degree)
  let root =
    if g.split: Node[T](keys: @[g.mid], kids: @[g.left, g.right])
    else: g.node
  BTree[T](degree: t.degree, root: root, size: t.size + 1)

func fromSeq*[T](minDegree: int; items: openArray[T]): Option[BTree[T]] {.raises: [].} =
  ## A tree of the distinct items; none when `minDegree` is below 2.
  let empty = newBTree[T](minDegree)
  if empty.isNone: return empty
  var t = empty.get
  for x in items:
    t = t.insert(x)
  some(t)

func collect[T](n: Node[T]; acc: var seq[T]) =
  if n.isNil: return
  for i in 0 ..< n.keys.len:
    if n.kids.len > 0: collect(n.kids[i], acc)
    acc.add n.keys[i]
  if n.kids.len > 0: collect(n.kids[n.keys.len], acc)

func toSortedSeq*[T](t: BTree[T]): seq[T] {.raises: [].} =
  ## The members in ascending order.
  collect(t.root, result)

iterator items*[T](t: BTree[T]): T {.raises: [].} =
  ## Members in ascending order.
  for x in t.toSortedSeq:
    yield x

func height*[T](t: BTree[T]): int {.raises: [].} =
  ## Number of levels (0 for the empty tree, 1 for a single leaf).
  var n = t.root
  while not n.isNil:
    inc result
    n = if n.kids.len == 0: nil else: n.kids[0]

func invariantsHold*[T](t: BTree[T]): bool {.raises: [].} =
  ## Key counts per node, child counts, equal leaf depth and strictly ascending in-order keys.
  let maxKeys = 2 * t.degree - 1
  let minKeys = t.degree - 1
  var leafDepth = -1
  func ok(n: Node[T]; depth: int; isRoot: bool; leafDepth: var int): bool =
    if n.keys.len > maxKeys or n.keys.len < (if isRoot: 1 else: minKeys): return false
    if n.kids.len == 0:
      if leafDepth < 0: leafDepth = depth
      return leafDepth == depth
    if n.kids.len != n.keys.len + 1: return false
    for k in n.kids:
      if not ok(k, depth + 1, false, leafDepth): return false
    true
  if t.root.isNil: return t.size == 0
  let order = t.toSortedSeq
  if order.len != t.size: return false
  for i in 1 ..< order.len:
    if not (order[i - 1] < order[i]): return false
  ok(t.root, 1, true, leafDepth)
