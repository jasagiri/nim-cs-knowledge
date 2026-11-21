## Generational slot map: handles into one owner instead of shared references.
##
## When several parts of a program need to refer to the same thing, the shortcut that compiles is a
## shared `ref` (and a lock or a counter around it). Here one owner, the `SlotMap`, holds every
## value in a flat `seq` of slots and gives out a `Handle` (slot index plus generation) per value.
## Other code keeps the handle, not the value, and asks the owner when it needs it. Removing a value
## bumps its slot's generation and puts the slot on a free list; `insert` reuses free slots first,
## so a handle to a removed value is rejected (`none`, `false`) even after its slot holds
## something else. The generation is an `int`; it would need 2^63 removals of one slot to wrap.
##
## Updates take the map as a `sink` parameter and return it with the result, so the caller moves the
## map in at its last use and the slots are not copied: `insert`, `put` and `remove` are O(1)
## (amortised for the `seq` growth). A caller that keeps using the old map gets a copy of the slots
## (O(n)) and an unchanged old value, as for every other structure in this repository. A failed
## `remove` or `put` still returns the map, so a moved-in map is never lost. Use it for entities, nodes
## and resources that are created, destroyed and referred to over time; the arena list in
## `linked_list` uses the same generation idea for list nodes.

import std/options

const
  noLink = 0   ## the end of the free list; a link holds a slot index plus one, so the zero value is empty

type
  Handle* = object
    ## A reference to one value: the slot and the generation the slot had when it was handed out.
    index*: int
    generation*: int
  Slot[T] = object
    live: bool
    generation: int
    elem: T
    nextFree: int       ## for a dead slot, the next slot of the free list (index + 1), or `noLink`
  SlotMap*[T] = object
    slots: seq[Slot[T]]
    freeHead: int       ## the first slot of the free list (index + 1), or `noLink`
    count: int

func emptySlotMap*[T](): SlotMap[T] {.raises: [].} =
  ## The empty map; `default(SlotMap[T])` is the same value.
  SlotMap[T]()

func len*[T](m: SlotMap[T]): int {.raises: [].} =
  m.count

func isEmpty*[T](m: SlotMap[T]): bool {.raises: [].} =
  m.count == 0

func `==`*(a, b: Handle): bool {.raises: [].} =
  a.index == b.index and a.generation == b.generation

func isLive[T](m: SlotMap[T]; h: Handle): bool =
  h.index >= 0 and h.index < m.slots.len and m.slots[h.index].live and
    m.slots[h.index].generation == h.generation

func contains*[T](m: SlotMap[T]; h: Handle): bool {.raises: [].} =
  m.isLive(h)

func get*[T](m: SlotMap[T]; h: Handle): Option[T] {.raises: [].} =
  if m.isLive(h): some(m.slots[h.index].elem) else: none(T)

func insert*[T](m: sink SlotMap[T]; x: sink T): tuple[map: SlotMap[T], handle: Handle] {.raises: [].} =
  ## Stores `x` in the first free slot, or in a new slot at the end when none is free.
  var r = m
  var at: int
  if r.freeHead != noLink:
    at = r.freeHead - 1
    r.freeHead = r.slots[at].nextFree
    r.slots[at].live = true
    r.slots[at].elem = x
    r.slots[at].nextFree = noLink
  else:
    at = r.slots.len
    r.slots.add Slot[T](live: true, generation: 0, elem: x, nextFree: noLink)
  inc r.count
  let h = Handle(index: at, generation: r.slots[at].generation)
  (r, h)

func remove*[T](m: sink SlotMap[T]; h: Handle): tuple[map: SlotMap[T], removed: Option[T]] {.raises: [].} =
  ## Takes the value out and retires the handle. A stale or unknown handle returns the map as it
  ## was and `none`.
  if not m.isLive(h): return (m, none(T))
  var r = m
  let taken = some(move r.slots[h.index].elem)
  r.slots[h.index].live = false
  inc r.slots[h.index].generation
  r.slots[h.index].nextFree = r.freeHead
  r.freeHead = h.index + 1
  dec r.count
  (r, taken)

func put*[T](m: sink SlotMap[T]; h: Handle; x: sink T): tuple[map: SlotMap[T], ok: bool] {.raises: [].} =
  ## Replaces the value a live handle names; the handle stays valid. A stale or unknown handle
  ## returns the map as it was and `false`.
  if not m.isLive(h): return (m, false)
  var r = m
  r.slots[h.index].elem = x
  (r, true)

iterator pairs*[T](m: SlotMap[T]): tuple[handle: Handle, value: T] {.raises: [].} =
  ## The live handles and values in slot order.
  for i in 0 ..< m.slots.len:
    if m.slots[i].live:
      yield (handle: Handle(index: i, generation: m.slots[i].generation), value: m.slots[i].elem)

func `==`*[T](a, b: SlotMap[T]): bool {.raises: [].} =
  ## Same slots, generations, live values, free list and count. Two maps that hold the same pairs
  ## but reached them by different insert and remove histories can differ here.
  if a.count != b.count or a.freeHead != b.freeHead or a.slots.len != b.slots.len: return false
  for i in 0 ..< a.slots.len:
    let x = a.slots[i]
    let y = b.slots[i]
    if x.live != y.live or x.generation != y.generation or x.nextFree != y.nextFree: return false
    if x.live and x.elem != y.elem: return false
  true

func invariantsHold*[T](m: SlotMap[T]): bool {.raises: [].} =
  ## `count` matches the live slots, every dead slot is on the free list exactly once, the free
  ## list holds nothing live, and every generation is non-negative.
  var live = 0
  for s in m.slots:
    if s.generation < 0: return false
    if s.live: inc live
  if live != m.count: return false
  var free = 0
  var f = m.freeHead
  while f != noLink:
    let i = f - 1
    if i < 0 or i >= m.slots.len or m.slots[i].live or free > m.slots.len: return false
    inc free
    f = m.slots[i].nextFree
  free + live == m.slots.len
