## Layer 1, the application service: text commands in, replies out. It imports only the domain.
##
## `parseCommand` turns a line into a `Command` or a message; `execute` applies one command to a
## board and returns the next board with the reply to show; `runLines` folds a whole log. All of
## it is pure, so the full behaviour of the program is a function from input lines to reply lines.

import nimcs/patterns/layered_architecture/domain

type
  CommandKind* = enum
    ckAdd, ckDone, ckList

  Command* = object
    case kind*: CommandKind
    of ckAdd:
      title*: string
    of ckDone:
      id*: int
    of ckList:
      discard

  RunResult* = object
    board*: Board
    replies*: seq[string]

func parseId(s: string): Result[int, string] {.raises: [].} =
  ## Digits only and at most six of them, so the conversion cannot overflow.
  if s.len == 0 or s.len > 6:
    return err(int, "bad id")
  var n = 0
  for c in s:
    if c < '0' or c > '9':
      return err(int, "bad id")
    n = n * 10 + (ord(c) - ord('0'))
  ok(n, string)

func parseCommand*(line: string): Result[Command, string] {.raises: [].} =
  var verb = line
  var rest = ""
  for i in 0 ..< line.len:
    if line[i] == ' ':
      verb = line[0 ..< i]
      rest = line[i + 1 .. ^1]
      break
  case verb
  of "add": ok(Command(kind: ckAdd, title: rest), string)
  of "done":
    let id = parseId(rest)
    if id.isOk: ok(Command(kind: ckDone, id: id.value), string) else: err(Command, id.error)
  of "list": ok(Command(kind: ckList), string)
  else: err(Command, "unknown command")

func render(b: Board): string {.raises: [].} =
  if b.tasks.len == 0: return "(empty)"
  for i, t in b.tasks:
    if i > 0: result.add "; "
    result.add $t.id & (if t.done: " [x] " else: " [ ] ") & t.title

func execute*(b: Board; c: Command): RunResult {.raises: [].} =
  case c.kind
  of ckAdd:
    let r = b.add(c.title)
    if r.isOk: RunResult(board: r.value, replies: @["added " & $r.value.nextId.pred & ": " & c.title])
    else: RunResult(board: b, replies: @["error: empty title"])
  of ckDone:
    let r = b.complete(c.id)
    if r.isOk: RunResult(board: r.value, replies: @["done " & $c.id])
    else: RunResult(board: b, replies: @["error: no task " & $c.id])
  of ckList:
    RunResult(board: b, replies: @[render(b)])

func runLine*(b: Board; line: string): RunResult {.raises: [].} =
  let c = parseCommand(line)
  if c.isOk: b.execute(c.value)
  else: RunResult(board: b, replies: @["error: " & c.error])

func runLines*(b: Board; lines: openArray[string]): RunResult {.raises: [].} =
  var cur = b
  var replies: seq[string]
  for l in lines:
    let r = cur.runLine(l)
    cur = r.board
    replies.add r.replies
  RunResult(board: cur, replies: replies)
