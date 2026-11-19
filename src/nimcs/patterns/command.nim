## Command: an edit is a value; undo is another value.
##
## Positions and lengths are byte offsets into a UTF-8 text. A command that would cut a multi-byte
## character (a position on a continuation byte) or insert invalid UTF-8 is refused, so a valid
## document stays valid and `inverse` always describes the edit that was applied.
##
## The OO pattern wraps a request in an object with `execute` and `undo` so it can be queued,
## logged and reversed. In Nim a command is plain data (an object variant), `apply` is a pure
## function from document and command to a new document, and undo is the inverse command, computed
## from the document as it was before the edit. The editor keeps two stacks of inverse/forward
## commands. Use it when operations must be replayed, logged, undone or sent elsewhere; when you
## only need "go back to an earlier state", keep the old values instead (see `memento`).

import std/unicode
import nimcs/fp/result

type
  CmdKind* = enum
    ckInsert, ckDelete

  Cmd* = object
    ## Insert `text` before index `pos`, or delete `len` characters starting at `pos`.
    case kind*: CmdKind
    of ckInsert:
      pos*: int
      text*: string
    of ckDelete:
      at*: int
      len*: int

  EditError* = enum
    eeOutOfRange, eeNotCharBoundary, eeInvalidUtf8, eeNothingToUndo, eeNothingToRedo

  Editor* = object
    text*: string
    undoStack*: seq[Cmd]   ## inverse commands, most recent last
    redoStack*: seq[Cmd]   ## forward commands that were undone, most recent last

func insertCmd*(pos: int; text: string): Cmd {.raises: [].} =
  Cmd(kind: ckInsert, pos: pos, text: text)

func deleteCmd*(at, len: int): Cmd {.raises: [].} =
  Cmd(kind: ckDelete, at: at, len: len)

func `==`*(a, b: Cmd): bool {.raises: [].} =
  if a.kind != b.kind: return false
  case a.kind
  of ckInsert: a.pos == b.pos and a.text == b.text
  of ckDelete: a.at == b.at and a.len == b.len

func `==`*(a, b: Editor): bool {.raises: [].} =
  a.text == b.text and a.undoStack == b.undoStack and a.redoStack == b.redoStack

func `$`*(c: Cmd): string {.raises: [].} =
  case c.kind
  of ckInsert: "insert(" & $c.pos & ", " & c.text & ")"
  of ckDelete: "delete(" & $c.at & ", " & $c.len & ")"

func initEditor*(text: string): Editor {.raises: [].} =
  Editor(text: text, undoStack: @[], redoStack: @[])

func onBoundary(doc: string; p: int): bool {.raises: [].} =
  ## `p` (already in `0 .. doc.len`) does not fall inside a multi-byte character.
  p == doc.len or (ord(doc[p]) and 0xC0) != 0x80

func checkInsert(doc: string; c: Cmd): Result[bool, EditError] {.raises: [].} =
  if c.pos < 0 or c.pos > doc.len: return err(bool, eeOutOfRange)
  if not onBoundary(doc, c.pos): return err(bool, eeNotCharBoundary)
  if validateUtf8(c.text) != -1: return err(bool, eeInvalidUtf8)
  ok(true, EditError)

func checkDelete(doc: string; c: Cmd): Result[bool, EditError] {.raises: [].} =
  if c.at < 0 or c.len < 0 or c.at > doc.len - c.len: return err(bool, eeOutOfRange)
  if not onBoundary(doc, c.at) or not onBoundary(doc, c.at + c.len):
    return err(bool, eeNotCharBoundary)
  ok(true, EditError)

func apply*(doc: string; cmd: Cmd): Result[string, EditError] {.raises: [].} =
  ## The pure transition. A command that points outside the document, into the middle of a
  ## character, or inserts invalid UTF-8 is an error, not a clamp.
  case cmd.kind
  of ckInsert:
    let c = checkInsert(doc, cmd)
    if c.isErr: return err(string, c.error)
    ok(doc[0 ..< cmd.pos] & cmd.text & doc[cmd.pos .. ^1], EditError)
  of ckDelete:
    let c = checkDelete(doc, cmd)
    if c.isErr: return err(string, c.error)
    ok(doc[0 ..< cmd.at] & doc[cmd.at + cmd.len .. ^1], EditError)

func inverse*(doc: string; cmd: Cmd): Result[Cmd, EditError] {.raises: [].} =
  ## The command that undoes `cmd` when run on the document produced from `doc`.
  ## It needs `doc` because a delete must remember what it removed. Same validity rules as `apply`.
  case cmd.kind
  of ckInsert:
    let c = checkInsert(doc, cmd)
    if c.isErr: return err(Cmd, c.error)
    ok(deleteCmd(cmd.pos, cmd.text.len), EditError)
  of ckDelete:
    let c = checkDelete(doc, cmd)
    if c.isErr: return err(Cmd, c.error)
    ok(insertCmd(cmd.at, doc[cmd.at ..< cmd.at + cmd.len]), EditError)

func exec*(ed: Editor; cmd: Cmd): Result[Editor, EditError] {.raises: [].} =
  ## Runs a new command: pushes its inverse on the undo stack and clears redo.
  let next = apply(ed.text, cmd)
  if next.isErr: return err(Editor, next.error)
  let inv = inverse(ed.text, cmd)
  if inv.isErr: return err(Editor, inv.error)
  ok(Editor(text: next.value, undoStack: ed.undoStack & inv.value, redoStack: @[]), EditError)

func undo*(ed: Editor): Result[Editor, EditError] {.raises: [].} =
  if ed.undoStack.len == 0: return err(Editor, eeNothingToUndo)
  let inv = ed.undoStack[^1]
  let back = apply(ed.text, inv)
  if back.isErr: return err(Editor, back.error)
  # The redo command is the inverse of the inverse, taken on the current text.
  let fwd = inverse(ed.text, inv)
  if fwd.isErr: return err(Editor, fwd.error)
  ok(Editor(text: back.value, undoStack: ed.undoStack[0 ..< ed.undoStack.len - 1],
            redoStack: ed.redoStack & fwd.value), EditError)

func redo*(ed: Editor): Result[Editor, EditError] {.raises: [].} =
  if ed.redoStack.len == 0: return err(Editor, eeNothingToRedo)
  let fwd = ed.redoStack[^1]
  let next = apply(ed.text, fwd)
  if next.isErr: return err(Editor, next.error)
  let inv = inverse(ed.text, fwd)
  if inv.isErr: return err(Editor, inv.error)
  ok(Editor(text: next.value, undoStack: ed.undoStack & inv.value,
            redoStack: ed.redoStack[0 ..< ed.redoStack.len - 1]), EditError)

func replay*(start: string; log: openArray[Cmd]): Result[string, EditError] {.raises: [].} =
  ## Folds a command log over a document; stops at the first failing command.
  var doc = start
  for c in log:
    let r = apply(doc, c)
    if r.isErr: return r
    doc = r.value
  ok(doc, EditError)
