## Object capability: authority only by reference (ADR-NCK-0002).
##
## A capability is a value that names a resource and, by existing, grants the right to use it in
## specific ways. There is no ambient authority: no function here reaches a file, a global or a
## clock on its own; every operation takes the capability (and the `Store` it acts on) as an
## argument, so reading a signature tells you what a routine may touch. `FileCap` is sealed (a
## private field and `{.requiresInit.}`), so code outside this module cannot write
## `FileCap(rights: ...)` or declare an empty one; the only ways to get one are `rootCap` and the
## attenuations `readOnly`, `restrict` and `narrow`, and each of them returns a capability that
## permits no more than the one it came from. Delegation is passing the value.
##
## Honest limit: Nim cannot hide `rootCap`, the one function that creates authority from nothing.
## The convention is the powerbox: call it only at the program's edge (`main`), and hand narrower
## capabilities inward. A review (or a text search) for `rootCap` finds every place that can
## create authority. The `Store` is a plain persistent value standing for the resource; a real
## program applies the same shape to a directory, a socket or a device.

import std/[options, strutils]
import nimcs/ds/hamt
import nimcs/fp/result

type
  Right* = enum
    rtRead, rtWrite

  CapError* = enum
    ceDenied      ## the capability lacks the right
    ceOutside     ## the path is not below the capability's prefix
    ceBadPath     ## empty, absolute, or containing an empty, `.` or `..` segment
    ceNotFound

  FileCap* {.requiresInit.} = object
    ## Rights and a path prefix (whole segments). The empty prefix covers every path.
    held: set[Right]
    base: seq[string]

  Store* = Hamt[string, string]

func segments(path: string): Option[seq[string]] =
  ## The segments of a relative path, or `none` if any segment is empty, `.` or `..`.
  if path.len == 0: return none(seq[string])
  let parts = path.split('/')
  for p in parts:
    if p.len == 0 or p == "." or p == "..": return none(seq[string])
  some(parts)

func rootCap*(rights: set[Right]): FileCap {.raises: [].} =
  ## Authority from nothing: call it once, at the program's edge.
  FileCap(held: rights, base: @[])

func rights*(c: FileCap): set[Right] {.raises: [].} = c.held

func prefix*(c: FileCap): string {.raises: [].} = c.base.join("/")

func `==`*(a, b: FileCap): bool {.raises: [].} = a.held == b.held and a.base == b.base

func restrict*(c: FileCap; keep: set[Right]): FileCap {.raises: [].} =
  ## Keeps only the rights in `keep`; it can drop rights, never add them.
  FileCap(held: c.held * keep, base: c.base)

func readOnly*(c: FileCap): FileCap {.raises: [].} = c.restrict({rtRead})

func narrow*(c: FileCap; sub: string): Result[FileCap, CapError] {.raises: [].} =
  ## A capability for the directory `sub` below this one's prefix (`sub` is a relative path).
  let s = segments(sub)
  if s.isNone: return err(FileCap, ceBadPath)
  ok(FileCap(held: c.held, base: c.base & s.get), CapError)

func check(c: FileCap; right: Right; path: string): Result[bool, CapError] =
  let s = segments(path)
  if s.isNone: return err(bool, ceBadPath)
  if right notin c.held: return err(bool, ceDenied)
  if s.get.len <= c.base.len: return err(bool, ceOutside)
  for i in 0 ..< c.base.len:
    if s.get[i] != c.base[i]: return err(bool, ceOutside)
  ok(true, CapError)

func permits*(c: FileCap; right: Right; path: string): bool {.raises: [].} =
  c.check(right, path).isOk

func emptyStore*(): Store {.raises: [].} = emptyHamt[string, string]()

func read*(store: Store; c: FileCap; path: string): Result[string, CapError] {.raises: [].} =
  let allowed = c.check(rtRead, path)
  if allowed.isErr: return err(string, allowed.error)
  let found = store.get(path)
  if found.isNone: err(string, ceNotFound) else: ok(found.get, CapError)

func write*(store: Store; c: FileCap; path, data: string): Result[Store, CapError] {.raises: [].} =
  ## Returns the new store; the argument is unchanged.
  let allowed = c.check(rtWrite, path)
  if allowed.isErr: return err(Store, allowed.error)
  ok(store.put(path, data), CapError)
