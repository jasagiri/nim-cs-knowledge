## Three-way merge: combine two edits (`ours`, `theirs`) of one common ancestor (`base`), keeping
## what only one side changed and reporting what both changed differently as a value.
##
## Two levels. `mergeKeyed` merges maps (a directory tree, path by path): each key is decided on
## its own from three `Option`s, and a key both sides changed differently is a `KeyConflict`.
## `merge3` merges sequences (diff3 on lines): `ours` and `theirs` are each aligned with `base`
## through `lcs`, the lines all three still share are `Stable`, and what lies between them is
## taken from the one side that changed it (`Clean`) or reported as a `Conflict`. Neither level
## raises or picks a side silently.

import std/[options, tables, algorithm, strutils]
import nimcs/algo/lcs

type
  KeyConflict*[V] = object
    ## A key both sides changed differently: its three versions, `none` for absent.
    key*: string
    base*, ours*, theirs*: Option[V]

  KeyedMerge*[V] = object
    ## The outcome of `mergeKeyed`: the merged map, or the keys that need a decision together
    ## with what was already settled.
    case isClean*: bool
    of true:
      merged*: Table[string, V]
    of false:
      resolved*: Table[string, V]
      conflicts*: seq[KeyConflict[V]]

  Side* = enum
    sOurs, sTheirs, sBoth

  ChunkKind* = enum
    ckStable, ckClean, ckConflict

  Chunk*[T] = object
    ## A piece of a sequence merge: lines all three share, lines one side (or both, the same
    ## way) changed, or a hunk both sides changed differently. A `Clean` chunk may be empty (a
    ## deletion).
    case kind*: ChunkKind
    of ckStable:
      stable*: seq[T]
    of ckClean:
      side*: Side
      taken*: seq[T]
    of ckConflict:
      base*, ours*, theirs*: seq[T]

# ─── keyed merge ────────────────────────────────────────────────────────────

func `==`*[V](a, b: KeyedMerge[V]): bool {.raises: [].} =
  ## Nim cannot derive `==` for an object variant.
  if a.isClean != b.isClean: return false
  if a.isClean: a.merged == b.merged
  else: a.resolved == b.resolved and a.conflicts == b.conflicts

func look[V](t: Table[string, V]; key: string): Option[V] {.raises: [].} =
  t.withValue(key, found):
    return some(found)
  none(V)

func swapSides*[V](c: KeyConflict[V]): KeyConflict[V] {.raises: [].} =
  ## The same conflict seen from the other side.
  KeyConflict[V](key: c.key, base: c.base, ours: c.theirs, theirs: c.ours)

func swapSides*[V](m: KeyedMerge[V]): KeyedMerge[V] {.raises: [].} =
  ## What `mergeKeyed(base, theirs, ours)` gives when `m` came from `mergeKeyed(base, ours, theirs)`.
  if m.isClean:
    result = m
  else:
    var swapped: seq[KeyConflict[V]] = @[]
    for c in m.conflicts: swapped.add swapSides(c)
    result = KeyedMerge[V](isClean: false, resolved: m.resolved, conflicts: swapped)

func mergeKeyed*[V](base, ours, theirs: Table[string, V]): KeyedMerge[V] {.raises: [].} =
  ## Per key: unchanged or changed the same way on both sides, take it; changed on one side only,
  ## take that side; changed differently on both (delete against modify included), conflict
  ## (STR-MERGE3-01..06). Absent is a value like any other, so a deletion is a change.
  var keys: seq[string] = @[]
  for k in base.keys: keys.add k
  for k in ours.keys: keys.add k
  for k in theirs.keys: keys.add k
  keys.sort()
  var settled = initTable[string, V]()
  var conflicts: seq[KeyConflict[V]] = @[]
  var previous = ""
  for i, k in keys:
    if i > 0 and k == previous: continue
    previous = k
    let b = base.look(k)
    let o = ours.look(k)
    let t = theirs.look(k)
    let chosen =
      if o == t or t == b: some(o)
      elif o == b: some(t)
      else: none(Option[V])
    if chosen.isSome:
      if chosen.get.isSome: settled[k] = chosen.get.get
    else:
      conflicts.add KeyConflict[V](key: k, base: b, ours: o, theirs: t)
  if conflicts.len == 0:
    KeyedMerge[V](isClean: true, merged: settled)
  else:
    KeyedMerge[V](isClean: false, resolved: settled, conflicts: conflicts)

func conflictKeys*[V](m: KeyedMerge[V]): seq[string] {.raises: [].} =
  ## The conflicting keys in ascending order; empty for a clean merge.
  result = @[]
  if not m.isClean:
    for c in m.conflicts: result.add c.key

# ─── sequence merge ─────────────────────────────────────────────────────────

func stable*[T](lines: seq[T]): Chunk[T] {.raises: [].} =
  Chunk[T](kind: ckStable, stable: lines)

func clean*[T](side: Side; taken: seq[T]): Chunk[T] {.raises: [].} =
  Chunk[T](kind: ckClean, side: side, taken: taken)

func conflict*[T](base, ours, theirs: seq[T]): Chunk[T] {.raises: [].} =
  Chunk[T](kind: ckConflict, base: base, ours: ours, theirs: theirs)

func swapSides*[T](chunks: seq[Chunk[T]]): seq[Chunk[T]] {.raises: [].} =
  ## What `merge3(base, theirs, ours)` gives when `chunks` came from `merge3(base, ours, theirs)`
  ## (STR-MERGE3-09).
  result = @[]
  for c in chunks:
    case c.kind
    of ckStable: result.add c
    of ckClean:
      let s = case c.side
        of sOurs: sTheirs
        of sTheirs: sOurs
        of sBoth: sBoth
      result.add clean(s, c.taken)
    of ckConflict: result.add conflict(c.base, c.theirs, c.ours)

func `==`*[T](a, b: Chunk[T]): bool {.raises: [].} =
  ## Nim cannot derive `==` for an object variant.
  if a.kind != b.kind: return false
  case a.kind
  of ckStable: a.stable == b.stable
  of ckClean: a.side == b.side and a.taken == b.taken
  of ckConflict: a.base == b.base and a.ours == b.ours and a.theirs == b.theirs

func matchOf[T](base, other: openArray[T]): seq[int] {.raises: [].} =
  ## For each base index, the index it is matched to in `other`, or -1. The matching is one
  ## embedding of `lcs(base, other)` into each side (leftmost), so it is increasing on both.
  let common = lcs(base, other)
  result = newSeq[int](base.len)
  for i in 0 ..< base.len: result[i] = -1
  var at = 0
  var inOther = 0
  for i in 0 ..< base.len:
    if at < common.len and base[i] == common[at]:
      while other[inOther] != common[at]: inc inOther
      result[i] = inOther
      inc inOther
      inc at

func slice[T](a: openArray[T]; lo, hiExcl: int): seq[T] {.raises: [].} =
  result = @[]
  for i in lo ..< hiExcl: result.add a[i]

func addStable[T](chunks: var seq[Chunk[T]]; lines: seq[T]) {.raises: [].} =
  if lines.len == 0: return
  if chunks.len > 0 and chunks[^1].kind == ckStable:
    for l in lines: chunks[^1].stable.add l
  else:
    chunks.add stable(lines)

func addRegion[T](chunks: var seq[Chunk[T]]; b, o, t: seq[T]) {.raises: [].} =
  ## One stretch between two lines that all three share.
  if b.len == 0 and o.len == 0 and t.len == 0: return
  if o == t:
    if o == b: chunks.addStable b
    else: chunks.add clean(sBoth, o)
  elif o == b: chunks.add clean(sTheirs, t)
  elif t == b: chunks.add clean(sOurs, o)
  else: chunks.add conflict(b, o, t)

func merge3*[T](base, ours, theirs: openArray[T]): seq[Chunk[T]] {.raises: [].} =
  ## diff3: the chunks, in order, that read as the merged sequence once every `Conflict` is
  ## decided (STR-MERGE3-07..11). Lines that `lcs` matches in `ours` and in `theirs` against the
  ## same base line are stable; each stretch between them is classified by comparing the three
  ## versions of it.
  let mo = matchOf(base, ours)
  let mt = matchOf(base, theirs)
  result = @[]
  var nextBase = 0
  var nextOurs = 0
  var nextTheirs = 0
  for i in 0 .. base.len:
    let atEnd = i == base.len
    if not atEnd and (mo[i] < 0 or mt[i] < 0): continue
    let inOurs = if atEnd: ours.len else: mo[i]
    let inTheirs = if atEnd: theirs.len else: mt[i]
    result.addRegion(base.slice(nextBase, i), ours.slice(nextOurs, inOurs), theirs.slice(nextTheirs, inTheirs))
    if not atEnd: result.addStable @[base[i]]
    nextBase = i + 1
    nextOurs = inOurs + 1
    nextTheirs = inTheirs + 1

func conflictCount*[T](chunks: seq[Chunk[T]]): int {.raises: [].} =
  for c in chunks:
    if c.kind == ckConflict: inc result

func mergeLines*[T](chunks: seq[Chunk[T]]): Option[seq[T]] {.raises: [].} =
  ## The merged sequence, or `none` while a conflict is open.
  var lines: seq[T] = @[]
  for c in chunks:
    case c.kind
    of ckStable: lines.add c.stable
    of ckClean: lines.add c.taken
    of ckConflict: return none(seq[T])
  some(lines)

func toLines*(text: string): seq[string] {.raises: [].} =
  ## Split on `\n`; a final newline ends the last line instead of starting an empty one.
  result = @[]
  if text.len == 0: return
  let parts = text.split('\n')
  let n = if text[^1] == '\n': parts.len - 1 else: parts.len
  for i in 0 ..< n: result.add parts[i]

func render*(chunks: seq[Chunk[string]]; oursLabel = "ours"; baseLabel = "base";
    theirsLabel = "theirs"): string {.raises: [].} =
  ## The text of a merge, one `\n`-ended line per element; each conflict is fenced as
  ## `<<<<<<< ours`, `||||||| base`, `=======`, `>>>>>>> theirs` (STR-MERGE3-12).
  result = ""
  for c in chunks:
    case c.kind
    of ckStable:
      for l in c.stable: result.add l & "\n"
    of ckClean:
      for l in c.taken: result.add l & "\n"
    of ckConflict:
      result.add "<<<<<<< " & oursLabel & "\n"
      for l in c.ours: result.add l & "\n"
      result.add "||||||| " & baseLabel & "\n"
      for l in c.base: result.add l & "\n"
      result.add "=======\n"
      for l in c.theirs: result.add l & "\n"
      result.add ">>>>>>> " & theirsLabel & "\n"
