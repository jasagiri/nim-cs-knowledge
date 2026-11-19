## Hash array mapped trie (HAMT): a persistent unordered map with O(log32 n) operations.
##
## The hash of a key is read five bits at a time; each trie node stores a 32-bit bitmap saying
## which of its 32 slots are used and keeps only the used slots in a compact `seq`. A slot holds
## a single pair, a child node, or (when all 60+ hash bits agree) a bucket of colliding pairs.
## `put` and `remove` copy one root-to-leaf path and share the rest. The hash comes from
## `std/hashes` (`hash(key)`), which is deterministic for ints and strings; iteration order
## follows hash bits, so it is never exposed: the only way to list entries is `toSortedSeq`.
## Use it for large maps that are updated functionally and need no key order; use `rb_tree` when
## you need ordered traversal.

import std/[hashes, options, algorithm, bitops]

const
  bits = 5
  mask = 31'u64
  maxLevel = 12     ## levels 0..12 consume 65 bits; deeper than that means identical hashes

type
  SlotKind = enum
    skPair, skNode, skBucket
  Node[K, V] = ref object
    bitmap: uint32
    slots: seq[Slot[K, V]]
  Slot[K, V] = object
    case kind: SlotKind
    of skPair:
      key: K
      val: V
    of skNode:
      child: Node[K, V]
    of skBucket:
      pairs: seq[(K, V)]
  Hamt*[K, V] = object
    root: Node[K, V]
    size: int

func emptyHamt*[K, V](): Hamt[K, V] {.raises: [].} =
  Hamt[K, V](root: Node[K, V]())

func len*[K, V](m: Hamt[K, V]): int {.raises: [].} =
  m.size

func chunk(h: uint64; level: int): int =
  int((h shr (level * bits)) and mask)

func positionOf(bitmap: uint32; idx: int): int =
  ## Index into `slots` of the slot for chunk `idx`.
  countSetBits(bitmap and ((1'u32 shl idx) - 1))

func hashOf[K](key: K): uint64 =
  uint64(hash(key))

func pairSlot[K, V](key: K; val: V): Slot[K, V] =
  Slot[K, V](kind: skPair, key: key, val: val)

func joinPairs[K, V](k1: K; v1: V; k2: K; v2: V; level: int): Slot[K, V] =
  ## A slot holding two pairs with different keys, as seen from a node at `level - 1`.
  if level > maxLevel:
    Slot[K, V](kind: skBucket, pairs: @[(k1, v1), (k2, v2)])
  else:
    let i1 = chunk(hashOf(k1), level)
    let i2 = chunk(hashOf(k2), level)
    if i1 == i2:
      Slot[K, V](kind: skNode, child: Node[K, V](bitmap: 1'u32 shl i1,
        slots: @[joinPairs(k1, v1, k2, v2, level + 1)]))
    elif i1 < i2:
      Slot[K, V](kind: skNode, child: Node[K, V](bitmap: (1'u32 shl i1) or (1'u32 shl i2),
        slots: @[pairSlot(k1, v1), pairSlot(k2, v2)]))
    else:
      Slot[K, V](kind: skNode, child: Node[K, V](bitmap: (1'u32 shl i1) or (1'u32 shl i2),
        slots: @[pairSlot(k2, v2), pairSlot(k1, v1)]))

func putInto[K, V](n: Node[K, V]; key: K; h: uint64; val: V; level: int): Node[K, V] =
  let idx = chunk(h, level)
  let bit = 1'u32 shl idx
  let pos = positionOf(n.bitmap, idx)
  var slots = n.slots
  if (n.bitmap and bit) == 0:
    slots.insert(pairSlot(key, val), pos)
    return Node[K, V](bitmap: n.bitmap or bit, slots: slots)
  let slot = n.slots[pos]
  case slot.kind
  of skPair:
    slots[pos] =
      if slot.key == key: pairSlot(key, val)
      else: joinPairs(slot.key, slot.val, key, val, level + 1)
  of skNode:
    slots[pos] = Slot[K, V](kind: skNode, child: putInto(slot.child, key, h, val, level + 1))
  of skBucket:
    var pairs = slot.pairs
    var found = false
    for p in pairs.mitems:
      if p[0] == key:
        p[1] = val
        found = true
    if not found: pairs.add (key, val)
    slots[pos] = Slot[K, V](kind: skBucket, pairs: pairs)
  Node[K, V](bitmap: n.bitmap, slots: slots)

func get*[K, V](m: Hamt[K, V]; key: K): Option[V] {.raises: [].} =
  if m.root.isNil: return none(V)
  let h = hashOf(key)
  var n = m.root
  var level = 0
  while true:
    let idx = chunk(h, level)
    if (n.bitmap and (1'u32 shl idx)) == 0: return none(V)
    let slot = n.slots[positionOf(n.bitmap, idx)]
    case slot.kind
    of skPair:
      return if slot.key == key: some(slot.val) else: none(V)
    of skNode:
      n = slot.child
      inc level
    of skBucket:
      for p in slot.pairs:
        if p[0] == key: return some(p[1])
      return none(V)

func contains*[K, V](m: Hamt[K, V]; key: K): bool {.raises: [].} =
  m.get(key).isSome

func put*[K, V](m: Hamt[K, V]; key: K; val: V): Hamt[K, V] {.raises: [].} =
  ## Inserts or replaces the value of `key`.
  let root = if m.root.isNil: Node[K, V]() else: m.root
  Hamt[K, V](root: putInto(root, key, hashOf(key), val, 0),
    size: if m.contains(key): m.size else: m.size + 1)

func removeFrom[K, V](n: Node[K, V]; key: K; h: uint64; level: int): Node[K, V] =
  ## Returns nil when the node becomes empty. Singleton nodes are not collapsed into their parent.
  let idx = chunk(h, level)
  let bit = 1'u32 shl idx
  if (n.bitmap and bit) == 0: return n
  let pos = positionOf(n.bitmap, idx)
  let slot = n.slots[pos]
  var slots = n.slots
  var bitmap = n.bitmap
  case slot.kind
  of skPair:
    if slot.key != key: return n
    slots.delete(pos)
    bitmap = bitmap and not bit
  of skNode:
    let child = removeFrom(slot.child, key, h, level + 1)
    if child == slot.child: return n
    if child.isNil:
      slots.delete(pos)
      bitmap = bitmap and not bit
    else:
      slots[pos] = Slot[K, V](kind: skNode, child: child)
  of skBucket:
    var pairs: seq[(K, V)]
    for p in slot.pairs:
      if p[0] != key: pairs.add p
    if pairs.len == slot.pairs.len: return n
    if pairs.len == 0:
      slots.delete(pos)
      bitmap = bitmap and not bit
    else:
      slots[pos] = Slot[K, V](kind: skBucket, pairs: pairs)
  if slots.len == 0: nil
  else: Node[K, V](bitmap: bitmap, slots: slots)

func remove*[K, V](m: Hamt[K, V]; key: K): Hamt[K, V] {.raises: [].} =
  ## The map without `key`; unchanged (and the same value) when the key is absent.
  if not m.contains(key): return m
  let root = removeFrom(m.root, key, hashOf(key), 0)
  Hamt[K, V](root: if root.isNil: Node[K, V]() else: root, size: m.size - 1)

func collect[K, V](n: Node[K, V]; into: var seq[(K, V)]) =
  for slot in n.slots:
    case slot.kind
    of skPair: into.add (slot.key, slot.val)
    of skNode: collect(slot.child, into)
    of skBucket:
      for p in slot.pairs:
        into.add p

func toSortedSeq*[K, V](m: Hamt[K, V]): seq[(K, V)] {.raises: [].} =
  ## All entries ordered by key. The trie's own order depends on the hash and is never exposed.
  if m.root.isNil: return
  collect(m.root, result)
  result.sort(proc(a, b: (K, V)): int = cmp(a[0], b[0]))

func fromPairs*[K, V](pairs: openArray[(K, V)]): Hamt[K, V] {.raises: [].} =
  ## Later pairs replace earlier ones with the same key.
  var m = emptyHamt[K, V]()
  for (k, v) in pairs:
    m = m.put(k, v)
  m
