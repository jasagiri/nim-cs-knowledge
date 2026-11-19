## Edit (Levenshtein) distance: the least number of single-character insertions, deletions and
## substitutions that turn one string into another, together with a script that does it.
##
## Use it for fuzzy matching, spelling suggestions and diffs at character level. The script is
## a list of `EditOp` values, and `applyScript` replays it, which makes the result checkable.
## For a diff that never substitutes, use `lcs` (insert/delete distance = len a + len b - 2 lcs).

import std/options

type
  EditKind* = enum
    ekKeep, ekReplace, ekInsert, ekDelete

  EditOp* = object
    case kind*: EditKind
    of ekKeep, ekInsert, ekDelete:
      ch*: char
    of ekReplace:
      before*, after*: char

func keep*(c: char): EditOp {.raises: [].} = EditOp(kind: ekKeep, ch: c)
func insert*(c: char): EditOp {.raises: [].} = EditOp(kind: ekInsert, ch: c)
func delete*(c: char): EditOp {.raises: [].} = EditOp(kind: ekDelete, ch: c)
func replace*(before, after: char): EditOp {.raises: [].} =
  EditOp(kind: ekReplace, before: before, after: after)

func `==`*(x, y: EditOp): bool {.raises: [].} =
  if x.kind != y.kind: return false
  case x.kind
  of ekKeep, ekInsert, ekDelete: x.ch == y.ch
  of ekReplace: x.before == y.before and x.after == y.after

func cost*(op: EditOp): int {.raises: [].} =
  ## Keeping is free; every other operation costs one.
  case op.kind
  of ekKeep: 0
  of ekReplace, ekInsert, ekDelete: 1

func cost*(script: openArray[EditOp]): int {.raises: [].} =
  for op in script:
    result += op.cost

func editDistance*(a, b: string): int {.raises: [].} =
  ## Levenshtein distance (DP-EDIT-01 .. DP-EDIT-04).
  var prev = newSeq[int](b.len + 1)
  var cur = newSeq[int](b.len + 1)
  for j in 0 .. b.len:
    prev[j] = j
  for i in 1 .. a.len:
    cur[0] = i
    for j in 1 .. b.len:
      let sub = prev[j - 1] + (if a[i - 1] == b[j - 1]: 0 else: 1)
      cur[j] = min(sub, min(prev[j] + 1, cur[j - 1] + 1))
    swap(prev, cur)
  prev[b.len]

func editScript*(a, b: string): seq[EditOp] {.raises: [].} =
  ## A cheapest script from `a` to `b`. On ties the backtrack prefers keep/replace, then delete,
  ## then insert, so the result is deterministic (DP-EDIT-05).
  let w = b.len + 1
  var table = newSeq[int]((a.len + 1) * w)
  for j in 0 .. b.len:
    table[j] = j
  for i in 1 .. a.len:
    table[i * w] = i
    for j in 1 .. b.len:
      let sub = table[(i - 1) * w + j - 1] + (if a[i - 1] == b[j - 1]: 0 else: 1)
      table[i * w + j] = min(sub, min(table[(i - 1) * w + j] + 1, table[i * w + j - 1] + 1))
  var i = a.len
  var j = b.len
  var rev: seq[EditOp] = @[]
  while i > 0 or j > 0:
    if i > 0 and j > 0 and
        table[i * w + j] == table[(i - 1) * w + j - 1] + (if a[i - 1] == b[j - 1]: 0 else: 1):
      rev.add(if a[i - 1] == b[j - 1]: keep(a[i - 1]) else: replace(a[i - 1], b[j - 1]))
      dec i
      dec j
    elif i > 0 and table[i * w + j] == table[(i - 1) * w + j] + 1:
      rev.add delete(a[i - 1])
      dec i
    else:
      rev.add insert(b[j - 1])
      dec j
  result = newSeq[EditOp](rev.len)
  for k in 0 ..< rev.len:
    result[k] = rev[rev.len - 1 - k]

func applyScript*(a: string; script: openArray[EditOp]): Option[string] {.raises: [].} =
  ## Replays `script` on `a`. None when the script does not fit `a`: it names a character `a`
  ## does not have at that place, or leaves part of `a` unread (DP-EDIT-06).
  var at = 0
  var outStr = ""
  for op in script:
    case op.kind
    of ekKeep:
      if at >= a.len or a[at] != op.ch: return none(string)
      outStr.add op.ch
      inc at
    of ekReplace:
      if at >= a.len or a[at] != op.before: return none(string)
      outStr.add op.after
      inc at
    of ekDelete:
      if at >= a.len or a[at] != op.ch: return none(string)
      inc at
    of ekInsert:
      outStr.add op.ch
  if at != a.len: none(string) else: some(outStr)
