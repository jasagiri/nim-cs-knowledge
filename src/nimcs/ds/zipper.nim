## Zippers: a cursor into an immutable list or binary tree.
##
## A zipper is the data structure turned inside out around one focus: the part you have passed
## is kept in reverse, ready to be put back. Moving the focus and replacing the focused element
## are O(1); rebuilding the whole structure costs one step per level you went down. Nothing is
## mutated: every move or edit gives a new zipper that shares the rest. Use it for editors,
## parsers that backtrack and tree rewriting where "change this place and keep everything else"
## is the operation; use plain recursion when you transform every node.

import std/options
import nimcs/ds/cons_list

type
  ListZipper*[T] = object
    before: ConsList[T]     ## elements left of the focus, nearest first
    focus: T
    after: ConsList[T]      ## elements right of the focus, nearest first

  Tree*[T] = object
    node: Node[T]           ## nil is the empty tree
  Node[T] = ref object
    value: T
    left, right: Tree[T]

  Direction = enum
    goLeft, goRight
  Crumb[T] = object
    dir: Direction          ## which child the focus is
    value: T                ## the parent's value
    other: Tree[T]          ## the sibling subtree
  TreeZipper*[T] = object
    focus: Tree[T]
    trail: ConsList[Crumb[T]]

# ---- list zipper ------------------------------------------------------------------------------

func zipList*[T](items: openArray[T]): Option[ListZipper[T]] {.raises: [].} =
  ## A zipper focused on the first element; none for an empty list.
  if items.len == 0: none(ListZipper[T])
  else: some(ListZipper[T](before: emptyList[T](), focus: items[0],
    after: fromSeq(items.toOpenArray(1, items.high))))

func focus*[T](z: ListZipper[T]): T {.raises: [].} =
  z.focus

func moveRight*[T](z: ListZipper[T]): Option[ListZipper[T]] {.raises: [].} =
  let next = z.after.head
  if next.isNone: none(ListZipper[T])
  else: some(ListZipper[T](before: z.before.cons(z.focus), focus: next.get, after: z.after.tail))

func moveLeft*[T](z: ListZipper[T]): Option[ListZipper[T]] {.raises: [].} =
  let prev = z.before.head
  if prev.isNone: none(ListZipper[T])
  else: some(ListZipper[T](before: z.before.tail, focus: prev.get, after: z.after.cons(z.focus)))

func setFocus*[T](z: ListZipper[T]; x: T): ListZipper[T] {.raises: [].} =
  ListZipper[T](before: z.before, focus: x, after: z.after)

func modify*[T](z: ListZipper[T]; f: proc(x: T): T {.noSideEffect, raises: [].}): ListZipper[T] {.raises: [].} =
  z.setFocus(f(z.focus))

func toSeq*[T](z: ListZipper[T]): seq[T] {.raises: [].} =
  ## The whole list, rebuilt.
  z.before.reverse.toSeq & @[z.focus] & z.after.toSeq

func position*[T](z: ListZipper[T]): int {.raises: [].} =
  ## Index of the focus.
  z.before.len

# ---- binary tree ------------------------------------------------------------------------------

func leaf*[T](): Tree[T] {.raises: [].} =
  Tree[T]()

func branch*[T](left: Tree[T]; value: T; right: Tree[T]): Tree[T] {.raises: [].} =
  Tree[T](node: Node[T](value: value, left: left, right: right))

func isLeaf*[T](t: Tree[T]): bool {.raises: [].} =
  t.node.isNil

func value*[T](t: Tree[T]): Option[T] {.raises: [].} =
  if t.isLeaf: none(T) else: some(t.node.value)

func `==`*[T](a, b: Tree[T]): bool {.raises: [].} =
  if a.isLeaf or b.isLeaf: a.isLeaf and b.isLeaf
  else: a.node.value == b.node.value and a.node.left == b.node.left and a.node.right == b.node.right

func toSeq*[T](t: Tree[T]): seq[T] {.raises: [].} =
  ## In-order traversal.
  if t.isLeaf: return
  result = t.node.left.toSeq & @[t.node.value] & t.node.right.toSeq

func zipTree*[T](t: Tree[T]): TreeZipper[T] {.raises: [].} =
  TreeZipper[T](focus: t, trail: emptyList[Crumb[T]]())

func focusTree*[T](z: TreeZipper[T]): Tree[T] {.raises: [].} =
  z.focus

func downLeft*[T](z: TreeZipper[T]): Option[TreeZipper[T]] {.raises: [].} =
  ## Moves to the left child; none at a leaf.
  if z.focus.isLeaf: none(TreeZipper[T])
  else:
    let n = z.focus.node
    some(TreeZipper[T](focus: n.left,
      trail: z.trail.cons(Crumb[T](dir: goLeft, value: n.value, other: n.right))))

func downRight*[T](z: TreeZipper[T]): Option[TreeZipper[T]] {.raises: [].} =
  if z.focus.isLeaf: none(TreeZipper[T])
  else:
    let n = z.focus.node
    some(TreeZipper[T](focus: n.right,
      trail: z.trail.cons(Crumb[T](dir: goRight, value: n.value, other: n.left))))

func up*[T](z: TreeZipper[T]): Option[TreeZipper[T]] {.raises: [].} =
  ## Moves to the parent, putting the (possibly edited) focus back; none at the root.
  let crumb = z.trail.head
  if crumb.isNone: none(TreeZipper[T])
  else:
    let c = crumb.get
    let rebuilt =
      case c.dir
      of goLeft: branch(z.focus, c.value, c.other)
      of goRight: branch(c.other, c.value, z.focus)
    some(TreeZipper[T](focus: rebuilt, trail: z.trail.tail))

func replace*[T](z: TreeZipper[T]; t: Tree[T]): TreeZipper[T] {.raises: [].} =
  ## Swaps the focused subtree for `t`.
  TreeZipper[T](focus: t, trail: z.trail)

func modify*[T](z: TreeZipper[T]; f: proc(x: T): T {.noSideEffect, raises: [].}): TreeZipper[T] {.raises: [].} =
  ## Applies `f` to the value at the focus; a focused leaf has no value and stays as it is.
  if z.focus.isLeaf: z
  else:
    let n = z.focus.node
    z.replace(branch(n.left, f(n.value), n.right))

func rebuild*[T](z: TreeZipper[T]): Tree[T] {.raises: [].} =
  ## Goes up to the root and returns the whole tree.
  var cur = z
  while true:
    let parent = cur.up
    if parent.isNone: return cur.focus
    cur = parent.get

func depth*[T](z: TreeZipper[T]): int {.raises: [].} =
  ## Number of steps down from the root.
  z.trail.len
