## Layer 2, the imperative shell: reads lines, calls the service, writes replies. Imports the service.
##
## The shell holds no rule. It is the one place with effects, so it is the one `proc`; the effects
## are handed in as procs (`readLine`, `writeLine`) so a test can drive it without a terminal.

import std/options
import nimcs/patterns/layered_architecture/[domain, service]

type
  LineSource* = proc(): Option[string] {.raises: [].}
  LineSink* = proc(s: string) {.raises: [].}

proc runShell*(readLine: LineSource; writeLine: LineSink): Board {.raises: [].} =
  ## A `proc`, not a `func`: it calls the two effectful procs it is given. Returns the final board.
  var board = emptyBoard()
  while true:
    let line = readLine()
    if line.isNone:
      break
    let r = board.runLine(line.get)
    board = r.board
    for reply in r.replies:
      writeLine(reply)
  board
