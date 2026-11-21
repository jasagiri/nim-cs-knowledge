## State-based CRDTs (conflict-free replicated data types) as plain values: `GCounter`, `PNCounter`,
## `LwwRegister` and `OrSet`.
##
## Each replica holds its own copy of the state and changes it locally with no coordination. Copies
## are brought together with `merge`, which is the join of a semilattice: commutative
## (`a.merge(b) == b.merge(a)`), associative and idempotent (`a.merge(a) == a`). Because of those
## three laws the order in which copies are merged, how often, and in how many groups, does not matter:
## replicas that have seen the same updates hold equal states, whatever route the updates took. Every
## local update is itself a merge with a small state (a one-count delta, a one-dot set), which is why
## an update can never lose information that a merge would keep.
##
## States are kept in a canonical form (sorted sequences, no zero entries, no duplicates), so `==` on
## two states is equality of what they know, not an accident of the order of operations. Nothing here
## iterates a hash table.
##
## Rules for the user. A `ReplicaId` must belong to one live copy of the state at a time: two copies
## that both update as replica `a` can lose increments (counters) or invent the same tag for two
## different additions (`OrSet`). `LwwRegister` order values by (stamp, replica, value), so the
## stamps must come from a clock the replicas roughly share, and a replica with a slow clock loses
## its writes; the value type needs a `<` that is a strict total order consistent with `==`. `OrSet`
## keeps a tombstone for every removed addition and never forgets one, so it grows with the number of
## removals. Counter values are `int`: overflow is a `Defect` (`OverflowDefect`), not a wrap.

import std/options
import nimcs/fp/result
export result

type
  CrdtError* = enum
    ceEmptyReplica          ## a replica id with an empty name
  ReplicaId* = distinct string

func `==`*(a, b: ReplicaId): bool {.borrow.}
func `<`*(a, b: ReplicaId): bool {.borrow.}
func `$`*(r: ReplicaId): string {.borrow.}

func replicaId*(name: string): Result[ReplicaId, CrdtError] {.raises: [].} =
  ## A replica id; the name must not be empty.
  if name.len == 0: err(ReplicaId, ceEmptyReplica)
  else: ok(ReplicaId(name), CrdtError)

# --- G-Counter ------------------------------------------------------------------------------------

type
  Slot = object
    replica: ReplicaId
    count: int            ## always > 0
  GCounter* = object
    ## A counter that only grows: one slot per replica that has counted.
    slots: seq[Slot]

func `==`(a, b: Slot): bool {.raises: [].} =
  a.replica == b.replica and a.count == b.count

func emptyGCounter*(): GCounter {.raises: [].} =
  GCounter(slots: @[])

func `==`*(a, b: GCounter): bool {.raises: [].} =
  a.slots == b.slots

func merge*(a, b: GCounter): GCounter {.raises: [].} =
  ## Slot by slot, the larger count (a replica that is missing counts 0).
  var i = 0
  var j = 0
  var slots: seq[Slot]
  while i < a.slots.len and j < b.slots.len:
    if a.slots[i].replica < b.slots[j].replica:
      slots.add a.slots[i]
      inc i
    elif b.slots[j].replica < a.slots[i].replica:
      slots.add b.slots[j]
      inc j
    else:
      slots.add Slot(replica: a.slots[i].replica, count: max(a.slots[i].count, b.slots[j].count))
      inc i
      inc j
  while i < a.slots.len:
    slots.add a.slots[i]
    inc i
  while j < b.slots.len:
    slots.add b.slots[j]
    inc j
  GCounter(slots: slots)

func countOf*(c: GCounter; r: ReplicaId): int {.raises: [].} =
  ## What replica `r` has counted so far.
  for s in c.slots:
    if s.replica == r: return s.count
  0

func value*(c: GCounter): int {.raises: [].} =
  ## The total over all replicas.
  for s in c.slots:
    result += s.count

func increment*(c: GCounter; r: ReplicaId; by: Natural = 1): GCounter {.raises: [].} =
  ## Replica `r` counts `by` more: a merge with a counter that holds `r`'s new total.
  if by == 0: return c
  c.merge(GCounter(slots: @[Slot(replica: r, count: c.countOf(r) + by)]))

# --- PN-Counter -----------------------------------------------------------------------------------

type
  PNCounter* = object
    ## A counter that goes up and down: a G-Counter of increments and one of decrements.
    ups, downs: GCounter

func emptyPNCounter*(): PNCounter {.raises: [].} =
  PNCounter(ups: emptyGCounter(), downs: emptyGCounter())

func `==`*(a, b: PNCounter): bool {.raises: [].} =
  a.ups == b.ups and a.downs == b.downs

func merge*(a, b: PNCounter): PNCounter {.raises: [].} =
  PNCounter(ups: a.ups.merge(b.ups), downs: a.downs.merge(b.downs))

func value*(c: PNCounter): int {.raises: [].} =
  ## Increments minus decrements, over all replicas.
  c.ups.value - c.downs.value

func increment*(c: PNCounter; r: ReplicaId; by: Natural = 1): PNCounter {.raises: [].} =
  PNCounter(ups: c.ups.increment(r, by), downs: c.downs)

func decrement*(c: PNCounter; r: ReplicaId; by: Natural = 1): PNCounter {.raises: [].} =
  PNCounter(ups: c.ups, downs: c.downs.increment(r, by))

# --- LWW-Register ---------------------------------------------------------------------------------

type
  LwwEntry[T] = object
    stamp: int
    replica: ReplicaId
    val: T
  LwwRegister*[T] = object
    ## A single value; of two writes the later wins. Later means a larger stamp, then a larger replica
    ## id, then a larger value, so every pair of different writes has a winner and merge is symmetric.
    cur: Option[LwwEntry[T]]

func entryLess[T](a, b: LwwEntry[T]): bool =
  if a.stamp != b.stamp: a.stamp < b.stamp
  elif a.replica != b.replica: a.replica < b.replica
  else: a.val < b.val

func `==`[T](a, b: LwwEntry[T]): bool =
  a.stamp == b.stamp and a.replica == b.replica and not (a.val < b.val) and not (b.val < a.val)

func emptyRegister*[T](): LwwRegister[T] {.raises: [].} =
  ## A register nobody has written; it loses to every write.
  LwwRegister[T](cur: none(LwwEntry[T]))

func `==`*[T](a, b: LwwRegister[T]): bool {.raises: [].} =
  if a.cur.isNone or b.cur.isNone: a.cur.isNone and b.cur.isNone
  else: a.cur.get == b.cur.get

func merge*[T](a, b: LwwRegister[T]): LwwRegister[T] {.raises: [].} =
  ## The later of the two writes.
  if a.cur.isNone: b
  elif b.cur.isNone: a
  elif entryLess(a.cur.get, b.cur.get): b
  else: a

func registerOf*[T](stamp: int; replica: ReplicaId; v: T): LwwRegister[T] {.raises: [].} =
  ## A register holding one write.
  LwwRegister[T](cur: some(LwwEntry[T](stamp: stamp, replica: replica, val: v)))

func write*[T](reg: LwwRegister[T]; stamp: int; replica: ReplicaId; v: T): LwwRegister[T] {.raises: [].} =
  ## A local write: a merge with a one-write register. A write with an older stamp than the
  ## register already holds does not replace it.
  reg.merge(registerOf(stamp, replica, v))

func value*[T](reg: LwwRegister[T]): Option[T] {.raises: [].} =
  if reg.cur.isNone: none(T) else: some(reg.cur.get.val)

func stamp*[T](reg: LwwRegister[T]): Option[int] {.raises: [].} =
  if reg.cur.isNone: none(int) else: some(reg.cur.get.stamp)

func writer*[T](reg: LwwRegister[T]): Option[ReplicaId] {.raises: [].} =
  if reg.cur.isNone: none(ReplicaId) else: some(reg.cur.get.replica)

# --- OR-Set ---------------------------------------------------------------------------------------

type
  Tag = object
    replica: ReplicaId
    n: int
  Dot[T] = object
    elem: T
    tag: Tag
  OrSet*[T] = object
    ## A set whose additions carry unique tags. `remove` cancels only the tags it has seen, so an
    ## addition made concurrently with a removal survives the merge ("add wins").
    adds: seq[Dot[T]]       ## strictly increasing by (elem, tag)
    removed: seq[Tag]       ## tombstones, strictly increasing

func `<`(a, b: Tag): bool =
  if a.replica != b.replica: a.replica < b.replica
  else: a.n < b.n

func `<`[T](a, b: Dot[T]): bool =
  if a.elem < b.elem: true
  elif b.elem < a.elem: false
  else: a.tag < b.tag

# sorted-sequence helpers, after the orders they use are declared

func unionSorted[T](a, b: seq[T]): seq[T] =
  ## The union of two strictly increasing sequences, strictly increasing; elements that are neither
  ## less nor greater than each other count once.
  var i = 0
  var j = 0
  while i < a.len and j < b.len:
    if a[i] < b[j]:
      result.add a[i]
      inc i
    elif b[j] < a[i]:
      result.add b[j]
      inc j
    else:
      result.add a[i]
      inc i
      inc j
  while i < a.len:
    result.add a[i]
    inc i
  while j < b.len:
    result.add b[j]
    inc j

func isMember[T](xs: seq[T]; x: T): bool =
  ## Binary search in a strictly increasing sequence.
  var lo = 0
  var hi = xs.len
  while lo < hi:
    let mid = lo + (hi - lo) div 2
    if xs[mid] < x: lo = mid + 1
    elif x < xs[mid]: hi = mid
    else: return true
  false

func emptyOrSet*[T](): OrSet[T] {.raises: [].} =
  OrSet[T](adds: @[], removed: @[])

func `==`*[T](a, b: OrSet[T]): bool {.raises: [].} =
  ## Same additions and same tombstones.
  if a.adds.len != b.adds.len or a.removed.len != b.removed.len: return false
  for i in 0 ..< a.adds.len:
    if a.adds[i] < b.adds[i] or b.adds[i] < a.adds[i]: return false
  for i in 0 ..< a.removed.len:
    if a.removed[i] < b.removed[i] or b.removed[i] < a.removed[i]: return false
  true

func merge*[T](a, b: OrSet[T]): OrSet[T] {.raises: [].} =
  ## The union of the additions and the union of the tombstones.
  OrSet[T](adds: unionSorted(a.adds, b.adds), removed: unionSorted(a.removed, b.removed))

func live[T](s: OrSet[T]; d: Dot[T]): bool =
  not s.removed.isMember(d.tag)

func contains*[T](s: OrSet[T]; x: T): bool {.raises: [].} =
  for d in s.adds:
    if not (d.elem < x) and not (x < d.elem) and s.live(d): return true
  false

func elements*[T](s: OrSet[T]): seq[T] {.raises: [].} =
  ## The members, in increasing order, each once.
  for d in s.adds:
    if s.live(d) and (result.len == 0 or result[result.len - 1] < d.elem):
      result.add d.elem

func len*[T](s: OrSet[T]): int {.raises: [].} =
  s.elements.len

func tombstoneCount*[T](s: OrSet[T]): int {.raises: [].} =
  ## How many removed additions are remembered; it only grows.
  s.removed.len

func nextTag[T](s: OrSet[T]; r: ReplicaId): Tag =
  var top = 0
  for d in s.adds:
    if d.tag.replica == r: top = max(top, d.tag.n)
  for t in s.removed:
    if t.replica == r: top = max(top, t.n)
  Tag(replica: r, n: top + 1)

func add*[T](s: OrSet[T]; r: ReplicaId; x: T): OrSet[T] {.raises: [].} =
  ## Replica `r` adds `x` under a tag it has not used before (one more than the largest it has made).
  let dot = Dot[T](elem: x, tag: s.nextTag(r))
  s.merge(OrSet[T](adds: @[dot], removed: @[]))

func remove*[T](s: OrSet[T]; x: T): OrSet[T] {.raises: [].} =
  ## Cancels every addition of `x` this copy has seen. Removing what is not a member changes nothing.
  var seen: seq[Tag]
  for d in s.adds:
    if not (d.elem < x) and not (x < d.elem): seen.add d.tag
  if seen.len == 0: return s
  s.merge(OrSet[T](adds: @[], removed: seen))
