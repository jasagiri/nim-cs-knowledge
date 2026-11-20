## Persistent treap: an ordered set whose balance comes from priorities derived from a seed.
##
## A treap is a binary search tree on the keys that is also a max-heap on a priority stored in each
## node. Here the priority is not drawn from a random generator: it is a fixed mixing function of
## the seed and the key, so the same seed and the same key set always give the same tree, whatever
## order the keys were inserted in. With priorities that behave like random numbers the expected
## height is O(log n). All updates are `split` and `merge`, which copy only the path they walk and
## share the rest, so every earlier version stays valid. Use it for an ordered set that also needs
## cheap `split` and `merge` (cutting a key range off, joining two disjoint sets); use `rb_tree`
## when a worst-case height bound matters more than the simple code. The key type needs `<` and
## `hash`.

import std/[hashes, options]
import nimcs/fp/result

type
  Node[K] = ref object
    key: K
    prio: uint64
    size: int
    left, right: Node[K]
  Treap*[K] = object
    root: Node[K]
    seed: uint64
  TreapError* = enum
    seedMismatch   ## the two treaps were made with different seeds, so their priorities disagree
    keysOverlap    ## some key of the left treap is not smaller than every key of the right one

func mix64(z0: uint64): uint64 =
  ## A bijective 64-bit finaliser (the splitmix64 steps); unsigned arithmetic wraps by definition.
  var z = z0 + 0x9E3779B97F4A7C15'u64
  z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9'u64
  z = (z xor (z shr 27)) * 0x94D049BB133111EB'u64
  z xor (z shr 31)

func priorityOf[K](seed: uint64; key: K): uint64 =
  ## The masked hash is non-negative, so the conversion to `uint64` keeps its value.
  mix64(seed xor mix64(uint64(int(hash(key)) and high(int))))

func emptyTreap*[K](seed: uint64 = 0'u64): Treap[K] {.raises: [].} =
  ## An empty treap whose priorities will all be derived from `seed`.
  Treap[K](seed: seed)

func seed*[K](t: Treap[K]): uint64 {.raises: [].} =
  t.seed

func sizeOf[K](n: Node[K]): int =
  if n.isNil: 0 else: n.size

func mk[K](key: K; prio: uint64; l, r: Node[K]): Node[K] =
  Node[K](key: key, prio: prio, size: 1 + sizeOf(l) + sizeOf(r), left: l, right: r)

func len*[K](t: Treap[K]): int {.raises: [].} =
  sizeOf(t.root)

func isEmpty*[K](t: Treap[K]): bool {.raises: [].} =
  t.root.isNil

func contains*[K](t: Treap[K]; key: K): bool {.raises: [].} =
  var n = t.root
  while not n.isNil:
    if key < n.key: n = n.left
    elif n.key < key: n = n.right
    else: return true
  false

func splitNodes[K](n: Node[K]; key: K): tuple[less: Node[K], found: bool, greater: Node[K]] =
  if n.isNil: (nil, false, nil)
  elif key < n.key:
    let s = splitNodes(n.left, key)
    (s.less, s.found, mk(n.key, n.prio, s.greater, n.right))
  elif n.key < key:
    let s = splitNodes(n.right, key)
    (mk(n.key, n.prio, n.left, s.less), s.found, s.greater)
  else:
    (n.left, true, n.right)

func mergeNodes[K](a, b: Node[K]): Node[K] =
  ## Every key of `a` must be smaller than every key of `b`.
  if a.isNil: b
  elif b.isNil: a
  elif a.prio >= b.prio: mk(a.key, a.prio, a.left, mergeNodes(a.right, b))
  else: mk(b.key, b.prio, mergeNodes(a, b.left), b.right)

func split*[K](t: Treap[K]; key: K): tuple[less: Treap[K], found: bool, greater: Treap[K]] {.raises: [].} =
  ## Cuts `t` at `key`: the keys below it, whether `key` was present, and the keys above it.
  let s = splitNodes(t.root, key)
  (Treap[K](root: s.less, seed: t.seed), s.found, Treap[K](root: s.greater, seed: t.seed))

func minKey*[K](t: Treap[K]): Option[K] {.raises: [].} =
  var n = t.root
  if n.isNil: return none(K)
  while not n.left.isNil:
    n = n.left
  some(n.key)

func maxKey*[K](t: Treap[K]): Option[K] {.raises: [].} =
  var n = t.root
  if n.isNil: return none(K)
  while not n.right.isNil:
    n = n.right
  some(n.key)

func merge*[K](a, b: Treap[K]): Result[Treap[K], TreapError] {.raises: [].} =
  ## Joins two treaps made with the same seed whose key ranges do not overlap (all of `a` below
  ## all of `b`). Anything else is reported, never merged into a broken tree.
  if a.seed != b.seed:
    return err(Treap[K], seedMismatch)
  let hi = a.maxKey
  let lo = b.minKey
  if hi.isSome and lo.isSome and not (hi.get < lo.get):
    return err(Treap[K], keysOverlap)
  ok(Treap[K](root: mergeNodes(a.root, b.root), seed: a.seed), TreapError)

func insert*[K](t: Treap[K]; key: K): Treap[K] {.raises: [].} =
  ## Adds `key`; inserting a key that is present returns `t` itself (idempotent).
  let s = splitNodes(t.root, key)
  if s.found: return t
  let middle = mk(key, priorityOf(t.seed, key), nil, nil)
  Treap[K](root: mergeNodes(mergeNodes(s.less, middle), s.greater), seed: t.seed)

func delete*[K](t: Treap[K]; key: K): Treap[K] {.raises: [].} =
  ## Removes `key`; removing an absent key returns `t` itself (idempotent).
  let s = splitNodes(t.root, key)
  if not s.found: return t
  Treap[K](root: mergeNodes(s.less, s.greater), seed: t.seed)

func fromSeq*[K](seed: uint64; items: openArray[K]): Treap[K] {.raises: [].} =
  var t = emptyTreap[K](seed)
  for x in items:
    t = t.insert(x)
  t

func collect[K](n: Node[K]; acc: var seq[K]) =
  if not n.isNil:
    collect(n.left, acc)
    acc.add n.key
    collect(n.right, acc)

func toSeq*[K](t: Treap[K]): seq[K] {.raises: [].} =
  ## The keys in ascending order.
  collect(t.root, result)

func collectPre[K](n: Node[K]; acc: var seq[K]) =
  if not n.isNil:
    acc.add n.key
    collectPre(n.left, acc)
    collectPre(n.right, acc)

func preorder*[K](t: Treap[K]): seq[K] {.raises: [].} =
  ## The keys in root-first order: two treaps have the same shape exactly when this agrees.
  collectPre(t.root, result)

func heightOf[K](n: Node[K]): int =
  if n.isNil: 0 else: 1 + max(heightOf(n.left), heightOf(n.right))

func height*[K](t: Treap[K]): int {.raises: [].} =
  heightOf(t.root)

func invariantsHold*[K](t: Treap[K]): bool {.raises: [].} =
  ## Keys strictly increasing, priorities equal to the seeded function of the key and not growing
  ## towards the leaves, and every stored size correct.
  func local(n: Node[K]; seed: uint64): bool =
    if n.isNil: true
    else:
      n.prio == priorityOf(seed, n.key) and n.size == 1 + sizeOf(n.left) + sizeOf(n.right) and
        (n.left.isNil or n.left.prio <= n.prio) and (n.right.isNil or n.right.prio <= n.prio) and
        local(n.left, seed) and local(n.right, seed)
  let keys = t.toSeq
  for i in 1 ..< keys.len:
    if not (keys[i - 1] < keys[i]): return false
  local(t.root, t.seed)
