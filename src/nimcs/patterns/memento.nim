## Memento: a snapshot is just an old value.
##
## The OO pattern exists because objects are mutable and hide their fields: to roll one back, you
## need a sealed copy of its private state that only the object can open. With value semantics the
## problem disappears: `let saved = settings` is the memento, later changes build *new* values and
## cannot reach it. The guarantee holds for values made of value fields; a `ref` field is copied as a
## pointer, so the data behind it is shared and a later change through the original shows in the
## snapshot (GOF-MEMENTO-08). Keep snapshotted state free of mutable `ref`s, or rebuild the referent
## when snapshotting. What is left to design is the history policy, shown here as `Timeline[T]`: the
## values before the present, the present, the values that were undone, and a capacity so the past
## cannot grow without bound. Use it for undo-by-snapshot of small or structurally shared values;
## for large state or replication, store commands instead (see `command`).

import std/options

type
  Timeline*[T] = object
    past: seq[T]      ## oldest first
    present: T
    future: seq[T]    ## the value to redo next is last
    capacity: int     ## at most this many past values are kept (>= 1)

func initTimeline*[T](start: T; capacity: int): Timeline[T] {.raises: [].} =
  ## `capacity` below 1 is raised to 1 so that one undo is always possible.
  Timeline[T](past: @[], present: start, future: @[], capacity: max(1, capacity))

func current*[T](t: Timeline[T]): T {.raises: [].} = t.present
func pastLen*[T](t: Timeline[T]): int {.raises: [].} = t.past.len
func futureLen*[T](t: Timeline[T]): int {.raises: [].} = t.future.len
func history*[T](t: Timeline[T]): seq[T] {.raises: [].} =
  ## Oldest first, ending with the present.
  t.past & t.present

func record*[T](t: Timeline[T]; v: T): Timeline[T] {.raises: [].} =
  ## Makes `v` the present. The old present becomes the newest past value, the oldest past value
  ## is dropped when the capacity is exceeded, and redo is cleared.
  var past = t.past & t.present
  if past.len > t.capacity: past = past[past.len - t.capacity .. ^1]
  Timeline[T](past: past, present: v, future: @[], capacity: t.capacity)

func undo*[T](t: Timeline[T]): Option[Timeline[T]] {.raises: [].} =
  if t.past.len == 0: return none(Timeline[T])
  some(Timeline[T](past: t.past[0 ..< t.past.len - 1], present: t.past[^1],
                   future: t.future & t.present, capacity: t.capacity))

func redo*[T](t: Timeline[T]): Option[Timeline[T]] {.raises: [].} =
  if t.future.len == 0: return none(Timeline[T])
  some(Timeline[T](past: t.past & t.present, present: t.future[^1],
                   future: t.future[0 ..< t.future.len - 1], capacity: t.capacity))
