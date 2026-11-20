## Persistent AVL tree: a self-balancing ordered set.
##
## A binary search tree in which, at every node, the heights of the two subtrees differ by at most
## one. Each node stores its height; after an insert or delete, `balance` restores the rule on the
## way back up the path with one single or double rotation. The rule keeps the height below
## 1.4405 log2(n + 2), so `insert`, `delete` and `contains` are O(log n) worst case. Nodes are
## immutable `ref`s, so an update copies only the path it walks and the old tree stays valid.
## Use it when lookups dominate (AVL trees are a little more rigidly balanced than red-black
## trees); use `rb_tree` for a map with the same guarantees. The item type needs `<`; two items
## are equal when neither is smaller.

import std/options

type
  Node[T] = ref object
    elem: T
    height: int
    left, right: Node[T]
  AvlTree*[T] = object
    root: Node[T]
    size: int

func emptyAvl*[T](): AvlTree[T] {.raises: [].} =
  AvlTree[T]()

func len*[T](t: AvlTree[T]): int {.raises: [].} =
  t.size

func isEmpty*[T](t: AvlTree[T]): bool {.raises: [].} =
  t.root.isNil

func heightOf[T](n: Node[T]): int =
  if n.isNil: 0 else: n.height

func mk[T](x: T; l, r: Node[T]): Node[T] =
  Node[T](elem: x, height: max(heightOf(l), heightOf(r)) + 1, left: l, right: r)

func balance[T](x: T; l, r: Node[T]): Node[T] =
  ## A node with item `x` and subtrees `l`, `r` that differ in height by at most two (what one
  ## insert or delete can cause); rotates when they differ by two.
  if heightOf(l) > heightOf(r) + 1:
    if heightOf(l.left) >= heightOf(l.right):
      mk(l.elem, l.left, mk(x, l.right, r))                              # single right rotation
    else:
      let m = l.right
      mk(m.elem, mk(l.elem, l.left, m.left), mk(x, m.right, r))          # left-right double rotation
  elif heightOf(r) > heightOf(l) + 1:
    if heightOf(r.right) >= heightOf(r.left):
      mk(r.elem, mk(x, l, r.left), r.right)                              # single left rotation
    else:
      let m = r.left
      mk(m.elem, mk(x, l, m.left), mk(r.elem, m.right, r.right))         # right-left double rotation
  else:
    mk(x, l, r)

func contains*[T](t: AvlTree[T]; x: T): bool {.raises: [].} =
  var n = t.root
  while not n.isNil:
    if x < n.elem: n = n.left
    elif n.elem < x: n = n.right
    else: return true
  false

func insertNode[T](n: Node[T]; x: T): Node[T] =
  if n.isNil: mk(x, nil, nil)
  elif x < n.elem: balance(n.elem, insertNode(n.left, x), n.right)
  elif n.elem < x: balance(n.elem, n.left, insertNode(n.right, x))
  else: n

func insert*[T](t: AvlTree[T]; x: T): AvlTree[T] {.raises: [].} =
  ## The tree with `x`; inserting an item that is already there returns the same tree.
  if t.contains(x): t
  else: AvlTree[T](root: insertNode(t.root, x), size: t.size + 1)

func removeMin[T](n: Node[T]): tuple[smallest: T, rest: Node[T]] =
  if n.left.isNil: (n.elem, n.right)
  else:
    let (m, l) = removeMin(n.left)
    (m, balance(n.elem, l, n.right))

func deleteNode[T](n: Node[T]; x: T): Node[T] =
  if n.isNil: n
  elif x < n.elem: balance(n.elem, deleteNode(n.left, x), n.right)
  elif n.elem < x: balance(n.elem, n.left, deleteNode(n.right, x))
  elif n.left.isNil: n.right
  elif n.right.isNil: n.left
  else:
    let (m, r) = removeMin(n.right)
    balance(m, n.left, r)

func delete*[T](t: AvlTree[T]; x: T): AvlTree[T] {.raises: [].} =
  ## The tree without `x`; a missing item leaves the tree as it was.
  if not t.contains(x): t
  else: AvlTree[T](root: deleteNode(t.root, x), size: t.size - 1)

func height*[T](t: AvlTree[T]): int {.raises: [].} =
  ## Number of nodes on the longest root-to-leaf path; 0 for the empty tree.
  heightOf(t.root)

func smallest*[T](t: AvlTree[T]): Option[T] {.raises: [].} =
  var n = t.root
  if n.isNil: return none(T)
  while not n.left.isNil:
    n = n.left
  some(n.elem)

func toSeq*[T](t: AvlTree[T]): seq[T] {.raises: [].} =
  ## The items in ascending order.
  func walk(n: Node[T]; acc: var seq[T]) =
    if not n.isNil:
      walk(n.left, acc)
      acc.add n.elem
      walk(n.right, acc)
  walk(t.root, result)

func fromSeq*[T](items: openArray[T]): AvlTree[T] {.raises: [].} =
  result = emptyAvl[T]()
  for x in items:
    result = result.insert(x)

func invariantsHold*[T](t: AvlTree[T]): bool {.raises: [].} =
  ## Search order, correct stored heights, and the AVL rule (subtree heights differ by at most
  ## one) at every node; `len` counts the nodes.
  func ok(n: Node[T]; lo, hi: Option[T]): bool =
    if n.isNil: true
    else:
      (lo.isNone or lo.get < n.elem) and (hi.isNone or n.elem < hi.get) and
        n.height == max(heightOf(n.left), heightOf(n.right)) + 1 and
        abs(heightOf(n.left) - heightOf(n.right)) <= 1 and
        ok(n.left, lo, some(n.elem)) and ok(n.right, some(n.elem), hi)
  func count(n: Node[T]): int =
    if n.isNil: 0 else: 1 + count(n.left) + count(n.right)
  ok(t.root, none(T), none(T)) and count(t.root) == t.size
