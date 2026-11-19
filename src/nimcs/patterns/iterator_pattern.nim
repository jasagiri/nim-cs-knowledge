## Iterator: traversal is a Nim `iterator`, or a cursor that is itself a value.
##
## The OO pattern hides a collection's structure behind an object with `hasNext`/`next`. Nim has the
## pattern built in: an `iterator` is the traversal and a `for` loop is the client. Two shapes are
## shown over an immutable binary search tree. `items` is an inline iterator (internal iteration:
## the loop body runs inside the traversal). `Cursor` is external iteration done functionally: a
## value holding the traversal's pending work, where `next` returns the element and the *next
## cursor*, so a cursor can be kept, copied and resumed any number of times. External iteration is
## what you need to walk two collections in lockstep (`mergeUnion`). Use `iterator` first; reach
## for `Cursor` only when two traversals must advance independently.

import std/options

type
  Tree* = ref Node
    ## Empty tree is `nil`. Nodes are immutable by convention.
  Node = object
    left, right: Tree
    value: int

  Cursor* = object
    ## The left spine still to visit; the top of `pending` is the next element.
    pending: seq[Tree]

func insert*(t: Tree; v: int): Tree {.raises: [].} =
  ## Returns a new tree containing `v`; `t` is unchanged and shares its untouched subtrees.
  ## A value already present is not added again (set semantics).
  if t.isNil: return Tree(value: v)
  if v < t.value: Tree(value: t.value, left: insert(t.left, v), right: t.right)
  elif v > t.value: Tree(value: t.value, left: t.left, right: insert(t.right, v))
  else: t

func fromSeq*(xs: openArray[int]): Tree {.raises: [].} =
  for x in xs: result = result.insert(x)

func pushSpine(stack: seq[Tree]; t: Tree): seq[Tree] {.raises: [].} =
  result = stack
  var cur = t
  while not cur.isNil:
    result.add cur
    cur = cur.left

func cursor*(t: Tree): Cursor {.raises: [].} =
  Cursor(pending: pushSpine(@[], t))

func next*(c: Cursor): Option[(int, Cursor)] {.raises: [].} =
  ## The next element in ascending order and the cursor after it; `none` at the end.
  if c.pending.len == 0: return none((int, Cursor))
  let node = c.pending[^1]
  let rest = c.pending[0 ..< c.pending.len - 1]
  some((node.value, Cursor(pending: pushSpine(rest, node.right))))

iterator items*(t: Tree): int =
  ## In-order (ascending) traversal. Internal iteration: use it in a `for` loop.
  var c = cursor(t)
  while true:
    let n = c.next
    if n.isNone: break
    yield n.get[0]
    c = n.get[1]

func toSeq*(t: Tree): seq[int] {.raises: [].} =
  for x in t.items: result.add x

func mergeUnion*(a, b: Tree): seq[int] {.raises: [].} =
  ## Ascending union of two trees, each element once, walking both with cursors in lockstep.
  var ca = cursor(a)
  var cb = cursor(b)
  while true:
    let na = ca.next
    let nb = cb.next
    if na.isNone and nb.isNone: break
    if nb.isNone or (na.isSome and na.get[0] < nb.get[0]):
      result.add na.get[0]
      ca = na.get[1]
    elif na.isNone or nb.get[0] < na.get[0]:
      result.add nb.get[0]
      cb = nb.get[1]
    else:
      result.add na.get[0]
      ca = na.get[1]
      cb = nb.get[1]
