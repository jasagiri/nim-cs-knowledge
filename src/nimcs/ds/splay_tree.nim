## Persistent splay tree: a binary search tree that moves the key it just touched to the root.
##
## A classic splay tree rearranges itself on every read, which a persistent value cannot do in
## place. Here `lookup` returns the new tree next to the answer, as `tuple[found: bool, tree:
## SplayTree[K]]`, and the caller keeps using the returned tree. The splay itself is the usual
## zig, zig-zig and zig-zag rotations, written as a recursion that copies the path it walks.
## Amortized O(log n) per operation holds only for a sequence of operations where each uses the
## tree the previous one returned. A single version used again and again has no such bound: its
## deepest key costs O(n) every time. Use it for access patterns with locality (the same few keys
## asked for repeatedly) in single-threaded code; use `rb_tree` or `treap` when any version may be
## queried at any time. The key type needs `<`.

import std/options

type
  NodeObj[K] = object
    key: K
    left, right: Node[K]
  Node[K] = ref NodeObj[K]
  SplayTree*[K] = object
    root: Node[K]
    size: int

proc `=destroy`[K](n: var NodeObj[K]) =
  ## A splay tree can be a chain as long as it is large (ascending inserts), so the default
  ## destructor would recurse once per node. A work list frees the nodes this tree owns alone; a
  ## node still reachable from another version (`isUniqueRef` is false) is left to its last owner.
  var pending: seq[Node[K]]
  if not n.left.isNil: pending.add move(n.left)
  if not n.right.isNil: pending.add move(n.right)
  while pending.len > 0:
    let c = pending.pop
    if isUniqueRef(c):
      if not c.left.isNil: pending.add move(c.left)
      if not c.right.isNil: pending.add move(c.right)
  reset(n.key)

func emptyTree*[K](): SplayTree[K] {.raises: [].} =
  SplayTree[K]()

func len*[K](t: SplayTree[K]): int {.raises: [].} =
  t.size

func isEmpty*[K](t: SplayTree[K]): bool {.raises: [].} =
  t.root.isNil

func mk[K](key: K; l, r: Node[K]): Node[K] =
  Node[K](key: key, left: l, right: r)

func splayNode[K](n: Node[K]; key: K): Node[K] =
  ## Rebuilds the tree so that `key`, or the last node visited when it is absent, is the root.
  if n.isNil: return n
  if key < n.key:
    let x = n.left
    if x.isNil: return n
    if key < x.key:                      # zig-zig: both steps go left
      let t = splayNode(x.left, key)
      if t.isNil: mk(x.key, x.left, mk(n.key, x.right, n.right))
      else: mk(t.key, t.left, mk(x.key, t.right, mk(n.key, x.right, n.right)))
    elif x.key < key:                    # zig-zag: left, then right
      let t = splayNode(x.right, key)
      if t.isNil: mk(x.key, x.left, mk(n.key, x.right, n.right))
      else: mk(t.key, mk(x.key, x.left, t.left), mk(n.key, t.right, n.right))
    else:                                # zig: the key is the left child
      mk(x.key, x.left, mk(n.key, x.right, n.right))
  elif n.key < key:
    let x = n.right
    if x.isNil: return n
    if x.key < key:                      # zig-zig: both steps go right
      let t = splayNode(x.right, key)
      if t.isNil: mk(x.key, mk(n.key, n.left, x.left), x.right)
      else: mk(t.key, mk(x.key, mk(n.key, n.left, x.left), t.left), t.right)
    elif key < x.key:                    # zig-zag: right, then left
      let t = splayNode(x.left, key)
      if t.isNil: mk(x.key, mk(n.key, n.left, x.left), x.right)
      else: mk(t.key, mk(n.key, n.left, t.left), mk(x.key, t.right, x.right))
    else:                                # zig: the key is the right child
      mk(x.key, mk(n.key, n.left, x.left), x.right)
  else:
    n

func lookup*[K](t: SplayTree[K]; key: K): tuple[found: bool, tree: SplayTree[K]] {.raises: [].} =
  ## Looks `key` up and returns the tree with the touched node moved to the root. Keep using
  ## `tree`: that is what makes the amortized bound hold. When `key` is absent the last node
  ## visited is splayed instead, which keeps the bound for failed searches too.
  let r = splayNode(t.root, key)
  let hit = not r.isNil and not (key < r.key) and not (r.key < key)
  (hit, SplayTree[K](root: r, size: t.size))

func contains*[K](t: SplayTree[K]; key: K): bool {.raises: [].} =
  ## A read that does not adapt the tree: it walks without copying and leaves `t` as it is. It
  ## answers the same as `lookup(key).found` but gives up the locality gain.
  var n = t.root
  while not n.isNil:
    if key < n.key: n = n.left
    elif n.key < key: n = n.right
    else: return true
  false

func insert*[K](t: SplayTree[K]; key: K): SplayTree[K] {.raises: [].} =
  ## Adds `key` and leaves it at the root. A key that is present is only splayed to the root, so
  ## the key set is unchanged (idempotent on the set).
  let r = splayNode(t.root, key)
  if r.isNil:
    return SplayTree[K](root: mk(key, nil, nil), size: 1)
  if key < r.key:
    SplayTree[K](root: mk(key, r.left, mk(r.key, nil, r.right)), size: t.size + 1)
  elif r.key < key:
    SplayTree[K](root: mk(key, mk(r.key, r.left, nil), r.right), size: t.size + 1)
  else:
    SplayTree[K](root: r, size: t.size)

func delete*[K](t: SplayTree[K]; key: K): SplayTree[K] {.raises: [].} =
  ## Removes `key`; an absent key leaves the key set unchanged (the tree is splayed to the last
  ## node visited).
  let r = splayNode(t.root, key)
  if r.isNil or key < r.key or r.key < key:
    return SplayTree[K](root: r, size: t.size)
  if r.left.isNil:
    return SplayTree[K](root: r.right, size: t.size - 1)
  # `key` is larger than everything on the left, so splaying it brings the left maximum to the
  # root with an empty right side; the old right subtree hangs there.
  let l = splayNode(r.left, key)
  SplayTree[K](root: mk(l.key, l.left, r.right), size: t.size - 1)

func fromSeq*[K](items: openArray[K]): SplayTree[K] {.raises: [].} =
  var t = emptyTree[K]()
  for x in items:
    t = t.insert(x)
  t

func rootKey*[K](t: SplayTree[K]): Option[K] {.raises: [].} =
  if t.root.isNil: none(K) else: some(t.root.key)

func depthOf*[K](t: SplayTree[K]; key: K): Option[int] {.raises: [].} =
  ## Number of edges from the root to `key`, or none when absent. Does not splay.
  var n = t.root
  var d = 0
  while not n.isNil:
    if key < n.key: n = n.left
    elif n.key < key: n = n.right
    else: return some(d)
    inc d
  none(int)

func collect[K](n: Node[K]; acc: var seq[K]) =
  if not n.isNil:
    collect(n.left, acc)
    acc.add n.key
    collect(n.right, acc)

func toSeq*[K](t: SplayTree[K]): seq[K] {.raises: [].} =
  ## The keys in ascending order.
  collect(t.root, result)

func invariantsHold*[K](t: SplayTree[K]): bool {.raises: [].} =
  ## Keys strictly increasing and the stored size equal to the number of nodes.
  let keys = t.toSeq
  if keys.len != t.size: return false
  for i in 1 ..< keys.len:
    if not (keys[i - 1] < keys[i]): return false
  true
