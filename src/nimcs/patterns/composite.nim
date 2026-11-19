## Composite as a recursive object variant plus a fold.
##
## The OO pattern lets clients treat a single object and a group of objects through one interface.
## In Nim the tree is one object variant (`File` or `Dir` holding a `seq` of children, no `ref`
## needed) and every operation on the whole tree is an instance of one `fold`. Use it for
## part-whole structures (file trees, UI trees, expressions); write new operations as folds
## instead of adding a method to every node kind.

type
  EntryKind* = enum
    ekFile, ekDir

  Entry* = object
    name*: string
    case kind*: EntryKind
    of ekFile:
      size*: int
    of ekDir:
      children*: seq[Entry]

func file*(name: string; size: int): Entry {.raises: [].} =
  Entry(name: name, kind: ekFile, size: size)

func dir*(name: string; children: seq[Entry]): Entry {.raises: [].} =
  Entry(name: name, kind: ekDir, children: children)

func fold*[A](e: Entry;
              onFile: proc(name: string; size: int): A {.noSideEffect, raises: [].};
              onDir: proc(name: string; parts: seq[A]): A {.noSideEffect, raises: [].}): A {.raises: [].} =
  ## The one recursion; every other operation below is a choice of `onFile` and `onDir`.
  case e.kind
  of ekFile:
    onFile(e.name, e.size)
  of ekDir:
    var parts: seq[A] = @[]
    for c in e.children:
      parts.add(fold(c, onFile, onDir))
    onDir(e.name, parts)

func totalSize*(e: Entry): int {.raises: [].} =
  e.fold(
    proc(name: string; size: int): int {.noSideEffect, raises: [].} = size,
    proc(name: string; parts: seq[int]): int {.noSideEffect, raises: [].} =
      var sum = 0
      for p in parts: sum += p
      sum)

func fileCount*(e: Entry): int {.raises: [].} =
  e.fold(
    proc(name: string; size: int): int {.noSideEffect, raises: [].} = 1,
    proc(name: string; parts: seq[int]): int {.noSideEffect, raises: [].} =
      var sum = 0
      for p in parts: sum += p
      sum)

func depth*(e: Entry): int {.raises: [].} =
  e.fold(
    proc(name: string; size: int): int {.noSideEffect, raises: [].} = 0,
    proc(name: string; parts: seq[int]): int {.noSideEffect, raises: [].} =
      var deepest = 0
      for p in parts:
        if p > deepest: deepest = p
      deepest + 1)

func leafSizes*(e: Entry): seq[int] {.raises: [].} =
  ## Sizes of all files, left to right.
  e.fold(
    proc(name: string; size: int): seq[int] {.noSideEffect, raises: [].} = @[size],
    proc(name: string; parts: seq[seq[int]]): seq[int] {.noSideEffect, raises: [].} =
      var all: seq[int] = @[]
      for p in parts: all.add(p)
      all)
