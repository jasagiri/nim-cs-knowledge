import std/[unittest, os, strutils, options]
import propcheck
import nimcs/patterns/layered_architecture

const Layers = ["domain", "service", "shell"]   # lowest first; a layer may import only lower ones

func importedLayers(source: string): seq[string] {.raises: [].} =
  ## The layer names that appear after `layered_architecture/` on the import lines of a module.
  for raw in source.splitLines:
    let line = raw.strip
    if line.startsWith("import ") and "layered_architecture/" in line:
      let tail = line.replace("[", " ").replace("]", " ").replace(",", " ").replace("/", " ")
      for word in tail.splitWhitespace:
        if word in Layers: result.add word

func violations(layer: string; source: string): seq[string] {.raises: [].} =
  let rank = Layers.find(layer)
  for imported in importedLayers(source):
    if Layers.find(imported) >= rank: result.add imported

proc layerSource(name: string): string {.raises: [IOError].} =
  readFile(currentSourcePath().parentDir / ".." / "src" / "nimcs" / "patterns" /
    "layered_architecture" / (name & ".nim"))

proc commandLines(): Gen[seq[string]] {.raises: [ValueError].} =
  seqOf(pick(["add milk", "add eggs", "add", "done 1", "done 2", "done 9", "done x", "done 1234567",
              "list", "bogus", "add a b"]), 0, 14)

# SPEC: PAT-LAYEREDARCHITECTURE-01
test "PAT-LAYEREDARCHITECTURE-01 Given any command log, when run through the layers and through the tangled routine, then the replies are equal":
  let outcome = check(commandLines(), proc(ls: seq[string]): bool {.raises: [CatchableError].} =
    emptyBoard().runLines(ls).replies == tangledBefore(ls))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-LAYEREDARCHITECTURE-02
test "PAT-LAYEREDARCHITECTURE-02 Given the module files, when their imports are read, then every layer imports only layers below it":
  for layer in Layers:
    let src = layerSource(layer)
    check violations(layer, src).len == 0
  check importedLayers(layerSource("domain")).len == 0
  check importedLayers(layerSource("shell")) == @["domain", "service"]
  check "domain" in importedLayers(layerSource("service"))
  # The check itself catches a violation: a domain that reaches up, and a service that imports a sibling.
  check violations("domain", "import nimcs/patterns/layered_architecture/shell") == @["shell"]
  check violations("service", "import nimcs/patterns/layered_architecture/[domain, service]") == @["service"]
  check violations("shell", "import nimcs/patterns/layered_architecture/[domain, service]").len == 0

# SPEC: PAT-LAYEREDARCHITECTURE-03
test "PAT-LAYEREDARCHITECTURE-03 Given a board, when completing a task, then it is idempotent and an unknown id is refused without change":
  let b = emptyBoard().add("a").value.add("b").value
  let once = b.complete(2)
  check once.isOk
  check once.value.complete(2).value == once.value
  check b.complete(3).error == deNoSuchTask
  check emptyBoard().add("").error == deEmptyTitle
  check b.tasks.len == 2 and not b.tasks[1].done   # the old board is untouched

# SPEC: PAT-LAYEREDARCHITECTURE-04
test "PAT-LAYEREDARCHITECTURE-04 Given a log, when split at any point, then running the halves in turn equals running the whole":
  let outcome = check(pair(commandLines(), commandLines()),
      proc(x: (seq[string], seq[string])): bool {.raises: [CatchableError].} =
    let first = emptyBoard().runLines(x[0])
    let second = first.board.runLines(x[1])
    let whole = emptyBoard().runLines(x[0] & x[1])
    whole.replies == first.replies & second.replies and whole.board == second.board)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-LAYEREDARCHITECTURE-05
test "PAT-LAYEREDARCHITECTURE-05 Given a scripted input, when the shell runs, then the output is what the service replies and the board is its final board":
  let ls = @["add milk", "add eggs", "done 2", "list", "nope"]
  var next = 0
  var written: seq[string]
  let read = proc(): Option[string] {.raises: [].} =
    if next < ls.len:
      next.inc
      some(ls[next - 1])
    else:
      none(string)
  let write = proc(s: string) {.raises: [].} = written.add s
  let final = runShell(read, write)
  check written == tangledBefore(ls)
  check final == emptyBoard().runLines(ls).board
  check written[3] == "1 [ ] milk; 2 [x] eggs"
