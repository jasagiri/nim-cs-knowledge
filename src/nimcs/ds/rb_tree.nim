## Persistent red-black tree: an ordered map (`RbMap`) and an ordered set (`RbSet`).
##
## A binary search tree whose nodes are coloured so that the root is black, no red node has a red
## child, and every path from a node to a leaf holds the same number of black nodes. Those rules
## keep the height at most 2 log2(n + 1), so `put`, `get` and `contains` are O(log n) worst case.
## `put` copies only the path it walks (O(log n) new nodes) and shares the rest with the old tree,
## which stays valid. Use it for ordered iteration, range-like queries and a deterministic order;
## use `hamt` for unordered lookup. Deletion is not provided: its case analysis is longer than is worth showing here;
## rebuild from `toSeq` without the key, or use `hamt` when you need `remove`.

import std/options

type
  Color = enum
    cRed, cBlack
  Node[K, V] = ref object
    red: bool
    key: K
    val: V
    left, right: Node[K, V]
  RbMap*[K, V] = object
    root: Node[K, V]
    size: int
  Unit = object        ## the value type of a set: no payload
  RbSet*[K] = object
    items: RbMap[K, Unit]

func emptyMap*[K, V](): RbMap[K, V] {.raises: [].} =
  RbMap[K, V]()

func len*[K, V](m: RbMap[K, V]): int {.raises: [].} =
  m.size

func isRed[K, V](n: Node[K, V]): bool =
  not n.isNil and n.red

func mk[K, V](red: bool; key: K; val: V; l, r: Node[K, V]): Node[K, V] =
  Node[K, V](red: red, key: key, val: val, left: l, right: r)

func balance[K, V](key: K; val: V; l, r: Node[K, V]): Node[K, V] =
  ## Builds a black node and repairs a red-red violation among its two upper levels (Okasaki).
  if isRed(l) and isRed(l.left):
    mk(true, l.key, l.val, mk(false, l.left.key, l.left.val, l.left.left, l.left.right),
      mk(false, key, val, l.right, r))
  elif isRed(l) and isRed(l.right):
    let m = l.right
    mk(true, m.key, m.val, mk(false, l.key, l.val, l.left, m.left), mk(false, key, val, m.right, r))
  elif isRed(r) and isRed(r.left):
    let m = r.left
    mk(true, m.key, m.val, mk(false, key, val, l, m.left), mk(false, r.key, r.val, m.right, r.right))
  elif isRed(r) and isRed(r.right):
    mk(true, r.key, r.val, mk(false, key, val, l, r.left),
      mk(false, r.right.key, r.right.val, r.right.left, r.right.right))
  else:
    mk(false, key, val, l, r)

func ins[K, V](n: Node[K, V]; key: K; val: V): Node[K, V] =
  if n.isNil: mk(true, key, val, nil, nil)
  elif key < n.key:
    if n.red: mk(true, n.key, n.val, ins(n.left, key, val), n.right)
    else: balance(n.key, n.val, ins(n.left, key, val), n.right)
  elif n.key < key:
    if n.red: mk(true, n.key, n.val, n.left, ins(n.right, key, val))
    else: balance(n.key, n.val, n.left, ins(n.right, key, val))
  else:
    mk(n.red, key, val, n.left, n.right)

func find[K, V](n: Node[K, V]; key: K): Node[K, V] =
  var cur = n
  while not cur.isNil:
    if key < cur.key: cur = cur.left
    elif cur.key < key: cur = cur.right
    else: return cur
  nil

func get*[K, V](m: RbMap[K, V]; key: K): Option[V] {.raises: [].} =
  let n = find(m.root, key)
  if n.isNil: none(V) else: some(n.val)

func contains*[K, V](m: RbMap[K, V]; key: K): bool {.raises: [].} =
  not find(m.root, key).isNil

func put*[K, V](m: RbMap[K, V]; key: K; val: V): RbMap[K, V] {.raises: [].} =
  ## Inserts or replaces the value of `key`.
  let grown = ins(m.root, key, val)
  let root = mk(false, grown.key, grown.val, grown.left, grown.right)  # the root is always black
  RbMap[K, V](root: root, size: if m.contains(key): m.size else: m.size + 1)

func graft[K, V](color: Color; key: K; val: V; left, right: RbMap[K, V]): RbMap[K, V] {.raises: [].} =
  ## Test-only: a node of the given colour over two subtrees, with no rebalancing and no check that
  ## the result is a valid red-black tree. Not exported, so no caller can build an invalid map; the
  ## tests reach it through `import nimcs/ds/rb_tree {.all.}` to show `invariantsHold` saying no.
  RbMap[K, V](root: mk(color == cRed, key, val, left.root, right.root),
    size: left.size + right.size + 1)

func toSeq*[K, V](m: RbMap[K, V]): seq[(K, V)] {.raises: [].} =
  ## Key/value pairs in increasing key order (in-order walk, explicit stack).
  var stack: seq[Node[K, V]]
  var cur = m.root
  while not cur.isNil or stack.len > 0:
    while not cur.isNil:
      stack.add cur
      cur = cur.left
    let n = stack.pop
    result.add (n.key, n.val)
    cur = n.right

func fromPairs*[K, V](pairs: openArray[(K, V)]): RbMap[K, V] {.raises: [].} =
  ## Later pairs replace earlier ones with the same key.
  var m = emptyMap[K, V]()
  for (k, v) in pairs:
    m = m.put(k, v)
  m

func height*[K, V](m: RbMap[K, V]): int {.raises: [].} =
  func h(n: Node[K, V]): int =
    if n.isNil: 0 else: 1 + max(h(n.left), h(n.right))
  h(m.root)

func invariantsHold*[K, V](m: RbMap[K, V]): bool {.raises: [].} =
  ## Black root, no red node with a red child, equal black height on all paths, every key strictly
  ## between the keys of the nearest ancestors on each side (so `get` finds it), and a stored size
  ## that matches the node count.
  func blackHeight(n, lo, hi: Node[K, V]): int =   # -1 when a rule is broken below `n`
    if n.isNil: return 1
    if not lo.isNil and not (lo.key < n.key): return -1
    if not hi.isNil and not (n.key < hi.key): return -1
    let l = blackHeight(n.left, lo, n)
    let r = blackHeight(n.right, n, hi)
    if l < 0 or r < 0 or l != r: return -1
    if n.red and (isRed(n.left) or isRed(n.right)): return -1
    l + (if n.red: 0 else: 1)
  not isRed(m.root) and blackHeight(m.root, nil, nil) > 0 and m.toSeq.len == m.size

func emptySet*[K](): RbSet[K] {.raises: [].} =
  RbSet[K]()

func len*[K](s: RbSet[K]): int {.raises: [].} =
  s.items.len

func incl*[K](s: RbSet[K]; key: K): RbSet[K] {.raises: [].} =
  RbSet[K](items: s.items.put(key, Unit()))

func contains*[K](s: RbSet[K]; key: K): bool {.raises: [].} =
  s.items.contains(key)

func toSeq*[K](s: RbSet[K]): seq[K] {.raises: [].} =
  for (k, _) in s.items.toSeq:
    result.add k

func fromSeq*[K](keys: openArray[K]): RbSet[K] {.raises: [].} =
  var s = emptySet[K]()
  for k in keys:
    s = s.incl(k)
  s

func invariantsHold*[K](s: RbSet[K]): bool {.raises: [].} =
  s.items.invariantsHold
