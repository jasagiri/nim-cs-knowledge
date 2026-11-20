## Unbalanced binary search tree, persistent: a set of ordered items.
##
## Every node holds one item, with smaller items in the left subtree and larger ones in the right.
## Nodes are immutable `ref`s; `insert` and `delete` copy only the path they walk and share the rest
## with the old tree, which stays valid. There is no rebalancing, so the cost of an operation is
## the depth of the tree: O(log n) for items that arrive in random order, O(n) when they arrive
## sorted (the tree degenerates into a list). Use it to learn the ordered-tree operations and the
## three depth-first traversals; use `rb_tree` or `avl_tree` when the input order is not under
## your control. The item type needs `<`; two items are equal when neither is smaller.

import std/options

type
  NodeObj[T] = object
    elem: T
    left, right: Node[T]
  Node[T] = ref NodeObj[T]
  Bst*[T] = object
    root: Node[T]
    size: int

proc `=destroy`[T](n: var NodeObj[T]) =
  ## A degenerate tree is as deep as it has items, so the default destructor would recurse once
  ## per node. A work list frees the nodes this tree owns alone; a node still reachable from
  ## another tree (`isUniqueRef` is false) is left to its last owner.
  var pending: seq[Node[T]]
  if not n.left.isNil: pending.add move(n.left)
  if not n.right.isNil: pending.add move(n.right)
  while pending.len > 0:
    let c = pending.pop
    if isUniqueRef(c):
      if not c.left.isNil: pending.add move(c.left)
      if not c.right.isNil: pending.add move(c.right)
  reset(n.elem)

func emptyBst*[T](): Bst[T] {.raises: [].} =
  Bst[T]()

func len*[T](t: Bst[T]): int {.raises: [].} =
  t.size

func isEmpty*[T](t: Bst[T]): bool {.raises: [].} =
  t.root.isNil

func contains*[T](t: Bst[T]; x: T): bool {.raises: [].} =
  var n = t.root
  while not n.isNil:
    if x < n.elem: n = n.left
    elif n.elem < x: n = n.right
    else: return true
  false

func insertNode[T](n: Node[T]; x: T): Node[T] =
  if n.isNil: Node[T](elem: x)
  elif x < n.elem: Node[T](elem: n.elem, left: insertNode(n.left, x), right: n.right)
  elif n.elem < x: Node[T](elem: n.elem, left: n.left, right: insertNode(n.right, x))
  else: n

func insert*[T](t: Bst[T]; x: T): Bst[T] {.raises: [].} =
  ## The tree with `x`; inserting an item that is already there returns the same tree.
  if t.contains(x): t
  else: Bst[T](root: insertNode(t.root, x), size: t.size + 1)

func removeMin[T](n: Node[T]): tuple[smallest: T, rest: Node[T]] =
  ## The smallest item of a non-empty subtree and the subtree without it.
  if n.left.isNil: (n.elem, n.right)
  else:
    let (m, l) = removeMin(n.left)
    (m, Node[T](elem: n.elem, left: l, right: n.right))

func deleteNode[T](n: Node[T]; x: T): Node[T] =
  if n.isNil: n
  elif x < n.elem: Node[T](elem: n.elem, left: deleteNode(n.left, x), right: n.right)
  elif n.elem < x: Node[T](elem: n.elem, left: n.left, right: deleteNode(n.right, x))
  elif n.left.isNil: n.right
  elif n.right.isNil: n.left
  else:
    let (m, r) = removeMin(n.right)       # the in-order successor takes the deleted node's place
    Node[T](elem: m, left: n.left, right: r)

func delete*[T](t: Bst[T]; x: T): Bst[T] {.raises: [].} =
  ## The tree without `x`; a missing item leaves the tree as it was.
  if not t.contains(x): t
  else: Bst[T](root: deleteNode(t.root, x), size: t.size - 1)

func smallest*[T](t: Bst[T]): Option[T] {.raises: [].} =
  var n = t.root
  if n.isNil: return none(T)
  while not n.left.isNil:
    n = n.left
  some(n.elem)

func largest*[T](t: Bst[T]): Option[T] {.raises: [].} =
  var n = t.root
  if n.isNil: return none(T)
  while not n.right.isNil:
    n = n.right
  some(n.elem)

func height*[T](t: Bst[T]): int {.raises: [].} =
  ## Number of nodes on the longest root-to-leaf path; 0 for the empty tree.
  func go(n: Node[T]): int =
    if n.isNil: 0 else: 1 + max(go(n.left), go(n.right))
  go(t.root)

func inOrder*[T](t: Bst[T]): seq[T] {.raises: [].} =
  ## Left subtree, node, right subtree: the items in ascending order.
  func walk(n: Node[T]; acc: var seq[T]) =
    if not n.isNil:
      walk(n.left, acc)
      acc.add n.elem
      walk(n.right, acc)
  walk(t.root, result)

func preOrder*[T](t: Bst[T]): seq[T] {.raises: [].} =
  ## Node, left subtree, right subtree: re-inserting this list in order rebuilds the same shape.
  func walk(n: Node[T]; acc: var seq[T]) =
    if not n.isNil:
      acc.add n.elem
      walk(n.left, acc)
      walk(n.right, acc)
  walk(t.root, result)

func postOrder*[T](t: Bst[T]): seq[T] {.raises: [].} =
  ## Left subtree, right subtree, node: every node comes after its descendants.
  func walk(n: Node[T]; acc: var seq[T]) =
    if not n.isNil:
      walk(n.left, acc)
      walk(n.right, acc)
      acc.add n.elem
  walk(t.root, result)

func ascendingChain*[T](items: openArray[T]): Option[Bst[T]] {.raises: [].} =
  ## The degenerate tree of strictly ascending items (every node has only a right child), built
  ## iteratively in O(n) from the largest item down; `none` when the items are not strictly
  ## ascending. It is the worst case of an unbalanced tree, made on purpose for tests and demos.
  for i in 1 ..< items.len:
    if not (items[i - 1] < items[i]): return none(Bst[T])
  var root: Node[T]
  for i in countdown(items.len - 1, 0):
    root = Node[T](elem: items[i], right: root)
  some(Bst[T](root: root, size: items.len))

func fromSeq*[T](items: openArray[T]): Bst[T] {.raises: [].} =
  ## Inserts the items left to right; the shape depends on that order.
  result = emptyBst[T]()
  for x in items:
    result = result.insert(x)

func invariantsHold*[T](t: Bst[T]): bool {.raises: [].} =
  ## Every item lies strictly between the bounds set by its ancestors, and `len` counts the nodes.
  func ok(n: Node[T]; lo, hi: Option[T]): bool =
    if n.isNil: true
    else:
      (lo.isNone or lo.get < n.elem) and (hi.isNone or n.elem < hi.get) and
        ok(n.left, lo, some(n.elem)) and ok(n.right, some(n.elem), hi)
  func count(n: Node[T]): int =
    if n.isNil: 0 else: 1 + count(n.left) + count(n.right)
  ok(t.root, none(T), none(T)) and count(t.root) == t.size
