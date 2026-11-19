## Flyweight as interning against an explicit immutable pool value.
##
## The OO pattern shares one object among many users when the objects are identical, to save memory
## and to make equality a cheap comparison. In Nim the shared thing is a `Sym` (an index) and the
## pool is a value you pass in and get back: `intern` returns the new pool and the symbol. No
## global table, so interning is deterministic and testable. `intern` copies the pool when it adds a
## string (O(pool)); to intern many strings use `internAll`, which copies once. Use it for many repeated strings
## (identifiers, font names, tags); skip it when the data is small or unique.

import std/[options, tables]

type
  Sym* = distinct int

  Pool* = object
    names: seq[string]
    index: Table[string, int]

func `==`*(a, b: Sym): bool {.borrow.}

func `==`*(a, b: Pool): bool {.raises: [].} =
  ## Pools are equal when they hold the same strings in the same order (`index` is derived).
  a.names == b.names

func initPool*(): Pool {.raises: [].} =
  Pool(names: @[], index: initTable[string, int]())

func size*(p: Pool): int {.raises: [].} =
  p.names.len

func intern*(p: Pool; s: string): tuple[pool: Pool, sym: Sym] {.raises: [].} =
  ## Symbols are numbered by first appearance. Interning a string the pool already holds returns
  ## the same pool and the same symbol (idempotent).
  if p.index.hasKey(s):
    (p, Sym(p.index.getOrDefault(s, 0)))
  else:
    var next = p
    let id = next.names.len
    next.names.add(s)
    next.index[s] = id
    (next, Sym(id))

func resolve*(p: Pool; sym: Sym): Option[string] {.raises: [].} =
  let i = int(sym)
  if i >= 0 and i < p.names.len: some(p.names[i]) else: none(string)

func internAll*(p: Pool; items: seq[string]): tuple[pool: Pool, syms: seq[Sym]] {.raises: [].} =
  ## Same result as interning one by one, but the pool is copied once, not once per new string.
  var next = p
  var syms: seq[Sym] = @[]
  for s in items:
    let known = next.index.getOrDefault(s, -1)
    if known >= 0:
      syms.add(Sym(known))
    else:
      let id = next.names.len
      next.names.add(s)
      next.index[s] = id
      syms.add(Sym(id))
  (next, syms)
