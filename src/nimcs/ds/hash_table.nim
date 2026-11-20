## Hash table with open addressing and linear probing, as a value type.
##
## All entries live in one flat `seq` of slots. A key starts at the slot its hash selects and, when
## that slot is taken, moves one slot forward (wrapping around) until it finds its key or an empty
## slot. `del` shifts the following entries of the probe run backwards instead of leaving
## tombstones, so a lookup never walks over dead slots. The capacity is a power of two and the load
## stays at or below three quarters, so a probe run always ends at an empty slot.
##
## The type is a value (ADR-NCK-0002): `put` and `del` return a new table and the old one stays
## valid. That costs a copy of the slot array per update, O(n), so the cheap way to build a table
## is `fromPairs` (one local table, O(1) amortized per entry) and the cheap way to update a table
## in a loop is to keep a `var` local to one routine. Inside one routine, `std/tables` is the better
## tool; reach for this module to see how a hash table works or when an immutable snapshot with
## a deterministic `sortedPairs` view is wanted, and for `hamt` when old versions must stay cheap.
## The key type needs `hash` and `==`; `sortedPairs` also needs `<`.

import std/[hashes, options, algorithm]

type
  Slot[K, V] = object
    used: bool
    key: K
    val: V
  HashTable*[K, V] = object
    slots: seq[Slot[K, V]]
    count: int

const
  minCapacity = 8

func emptyTable*[K, V](): HashTable[K, V] {.raises: [].} =
  HashTable[K, V]()

func len*[K, V](t: HashTable[K, V]): int {.raises: [].} =
  t.count

func isEmpty*[K, V](t: HashTable[K, V]): bool {.raises: [].} =
  t.count == 0

func homeOf[K](key: K; capacity: int): int =
  ## The slot where a key's probe run starts; `capacity` is a power of two.
  int(hash(key)) and (capacity - 1)

func locate[K, V](slots: seq[Slot[K, V]]; key: K): tuple[found: bool, index: int] =
  ## Follows the probe run of `key`: the slot holding it, or the empty slot that ends the run.
  ## The caller guarantees `slots` is non-empty and not full.
  var i = homeOf(key, slots.len)
  while slots[i].used and slots[i].key != key:
    i = (i + 1) and (slots.len - 1)
  (slots[i].used, i)

func rehashed[K, V](slots: seq[Slot[K, V]]; capacity: int): seq[Slot[K, V]] =
  result = newSeq[Slot[K, V]](capacity)
  for s in slots:
    if s.used:
      var i = homeOf(s.key, capacity)
      while result[i].used:
        i = (i + 1) and (capacity - 1)
      result[i] = s

func put*[K, V](t: HashTable[K, V]; key: K; val: V): HashTable[K, V] {.raises: [].} =
  ## The table with `key` bound to `val`; an existing binding is replaced. O(n) because the slot
  ## array is copied; use `fromPairs` to add many entries.
  var slots = if t.slots.len == 0: newSeq[Slot[K, V]](minCapacity) else: t.slots
  let at = locate(slots, key)
  if at.found:
    slots[at.index].val = val
    HashTable[K, V](slots: slots, count: t.count)
  else:
    if (t.count + 1) * 4 > slots.len * 3:
      slots = rehashed(slots, slots.len * 2)
    let i = locate(slots, key).index
    slots[i] = Slot[K, V](used: true, key: key, val: val)
    HashTable[K, V](slots: slots, count: t.count + 1)

func get*[K, V](t: HashTable[K, V]; key: K): Option[V] {.raises: [].} =
  if t.count == 0: none(V)
  else:
    let at = locate(t.slots, key)
    if at.found: some(t.slots[at.index].val) else: none(V)

func contains*[K, V](t: HashTable[K, V]; key: K): bool {.raises: [].} =
  t.get(key).isSome

func shiftBack[K, V](slots: var seq[Slot[K, V]]; hole: int) =
  ## Closes the hole left by a deleted entry: a later entry of the same run moves into it when
  ## its home slot is not strictly between the hole and the entry (cyclically).
  let mask = slots.len - 1
  var hole = hole
  var j = hole
  while true:
    j = (j + 1) and mask
    if not slots[j].used: break
    let home = homeOf(slots[j].key, slots.len)
    let distHome = (j - home) and mask      # how far the entry sits from its home slot
    let distHole = (j - hole) and mask      # how far the hole is behind the entry
    if distHome >= distHole:
      slots[hole] = slots[j]
      slots[j] = Slot[K, V]()
      hole = j
  slots[hole] = Slot[K, V]()

func del*[K, V](t: HashTable[K, V]; key: K): HashTable[K, V] {.raises: [].} =
  ## The table without `key`; a missing key leaves the table as it was. O(n): the slot array is copied.
  if t.count == 0: t
  else:
    var slots = t.slots
    let at = locate(slots, key)
    if not at.found: t
    else:
      slots.shiftBack(at.index)
      HashTable[K, V](slots: slots, count: t.count - 1)

func fromPairs*[K, V](pairs: openArray[(K, V)]): HashTable[K, V] {.raises: [].} =
  ## Builds a table in one pass over a local slot array; for a repeated key the last pair wins.
  var slots = newSeq[Slot[K, V]](minCapacity)
  var count = 0
  for (k, v) in pairs:
    let at = locate(slots, k)
    if at.found:
      slots[at.index].val = v
    else:
      if (count + 1) * 4 > slots.len * 3:
        slots = rehashed(slots, slots.len * 2)
      let i = locate(slots, k).index
      slots[i] = Slot[K, V](used: true, key: k, val: v)
      inc count
  HashTable[K, V](slots: slots, count: count)

func sortedPairs*[K, V](t: HashTable[K, V]): seq[(K, V)] {.raises: [].} =
  ## All entries ordered by key. The slot order depends on the hash function and the history of the
  ## table, so it is never exposed; this view is the deterministic one (ADR-NCK-0002 S7).
  for s in t.slots:
    if s.used:
      result.add (s.key, s.val)
  result.sort(func(a, b: (K, V)): int = cmp(a[0], b[0]))

func invariantsHold*[K, V](t: HashTable[K, V]): bool {.raises: [].} =
  ## The capacity is zero or a power of two, `count` matches the used slots, the load is at most
  ## three quarters, and every entry is reachable from its home slot without crossing an empty slot.
  if t.slots.len == 0: return t.count == 0
  let cap = t.slots.len
  if (cap and (cap - 1)) != 0 or t.count * 4 > cap * 3: return false
  var used = 0
  for i in 0 ..< cap:
    if t.slots[i].used:
      inc used
      var j = homeOf(t.slots[i].key, cap)
      while j != i:
        if not t.slots[j].used: return false
        j = (j + 1) and (cap - 1)
  used == t.count
