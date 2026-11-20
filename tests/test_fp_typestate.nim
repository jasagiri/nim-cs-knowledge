import std/[unittest, os, osproc, strutils]
import propcheck
import nimcs/fp/[result, typestate]

const
  root = currentSourcePath().parentDir.parentDir
  chunkAlphabet = "ab\0\n z"

proc draftOf(chunks: seq[string]): Blob[Draft] {.raises: [].} =
  result = newDraft()
  for c in chunks:
    result = result.write(c)

proc compileOutcome(code: string): tuple[output: string, exitCode: int] {.raises: [CatchableError].} =
  ## Compiles `code` alone under the repository's lint settings, without writing an executable.
  let work = getTempDir() / "nck-typestate-" & $getCurrentProcessId()
  removeDir(work)
  createDir(work)
  var cfg = "--path:\"" & root / "src" & "\"\n"
  for line in readFile(root / "nim.cfg").splitLines:
    if line.startsWith("--") and "--path" notin line: cfg.add line & "\n"
  writeFile(work / "nim.cfg", cfg)
  writeFile(work / "example.nim", code)
  result = execCmdEx("nim c --hints:off --compileOnly example.nim", workingDir = work)
  removeDir(work)

# SPEC: FP-TYPESTATE-01
test "FP-TYPESTATE-01 Given any chunks written to a draft, when it is published, then the blob reads exactly what was written":
  let outcome = check(seqOf(stringOf(chunkAlphabet, 0, 6), 0, 6), proc(chunks: seq[string]): bool {.raises: [CatchableError].} =
    let d = draftOf(chunks)
    let p = d.publish
    p.read == chunks.join("") and p.size == chunks.join("").len and d.read == p.read)
  checkpoint describe(outcome)
  check outcome.passed
  check newDraft().read == ""
  check newDraft().write("ab").write("c").read == "abc"

# SPEC: FP-TYPESTATE-02
test "FP-TYPESTATE-02 Given a published blob or a draft, when an operation of the other state is applied, then it does not compile":
  let d = newDraft().write("x")
  let p = d.publish
  check compiles(d.write("y"))
  check compiles(p.contentId)
  check compiles(p.read)
  check compiles(d.read)
  check not compiles(p.write("y"))
  check not compiles(p.publish)
  check not compiles(d.contentId)
  check not compiles(Blob[Published](bytes: "forged"))
  check not compiles(block:
    var unset: Blob[Published]
    unset)
  check not compiles(block:
    let wrong: Blob[Published] = d
    wrong)

# SPEC: FP-TYPESTATE-03
test "FP-TYPESTATE-03 Given equal content written in different pieces, when published, then the content id is equal, and a later write to the draft does not change the published blob":
  let outcome = check(seqOf(stringOf(chunkAlphabet, 0, 6), 0, 6), proc(chunks: seq[string]): bool {.raises: [CatchableError].} =
    let whole = newDraft().write(chunks.join(""))
    let a = draftOf(chunks).publish
    let b = whole.publish
    a.contentId == b.contentId and a.contentId == draftOf(chunks).publish.contentId and a == b)
  checkpoint describe(outcome)
  check outcome.passed
  check newDraft().write("a").publish.contentId != newDraft().write("b").publish.contentId
  let stale = newDraft().write("verified")
  let p = stale.publish
  let later = stale.write(" and overwritten")
  check p.read == "verified"
  check later.read == "verified and overwritten"
  check ($p.contentId).len == 16

# SPEC: FP-TYPESTATE-04
test "FP-TYPESTATE-04 Given any record, when the bridge reads it, then it accepts exactly a draft record as a draft and a published record with the right id as published":
  let records = pair(pair(pick([rsDraft, rsPublished]), stringOf(chunkAlphabet, 0, 8)), intIn(0, 2)).map(
    proc(p: ((RecordState, string), int)): Stored {.raises: [].} =
      let good = store(newDraft().write(p[0][1]).publish).id
      let id = if p[1] == 0: good else: good & "0"
      case p[0][0]
      of rsDraft: Stored(state: rsDraft, bytes: p[0][1])
      of rsPublished: Stored(state: rsPublished, bytes: p[0][1], id: id))
  let outcome = check(records, proc(r: Stored): bool {.raises: [CatchableError].} =
    let asD = r.asDraft
    let asP = r.asPublished
    let goodId = $newDraft().write(r.bytes).publish.contentId
    let draftOk = r.state == rsDraft
    let pubOk = r.state == rsPublished and r.id == goodId
    (asD.isOk == draftOk) and (asP.isOk == pubOk) and
      (not draftOk or asD.value.read == r.bytes) and (not pubOk or asP.value.read == r.bytes) and
      (draftOk or asD.error == seNotDraft) and
      (pubOk or r.state != rsPublished or asP.error == seIdMismatch) and
      (r.state != rsDraft or asP.error == seNotPublished))
  checkpoint describe(outcome)
  check outcome.passed
  let wrongId = Stored(state: rsPublished, bytes: "x", id: "0000000000000000")
  check wrongId.asPublished.error == seIdMismatch

# SPEC: FP-TYPESTATE-05
test "FP-TYPESTATE-05 Given any blob, when it is stored and read back through the bridge, then it is the same blob in the same state and not in the other":
  let outcome = check(stringOf(chunkAlphabet, 0, 10), proc(s: string): bool {.raises: [CatchableError].} =
    let d = newDraft().write(s)
    let p = d.publish
    d.store.asDraft.isOk and d.store.asDraft.value == d and d.store.asPublished.isErr and
      p.store.asPublished.isOk and p.store.asPublished.value == p and p.store.asDraft.isErr)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-TYPESTATE-06
test "FP-TYPESTATE-06 Given a record of unknown state, when writeStored and publishStored are applied, then they agree with the typed ones and a published record is refused with a value":
  let outcome = check(pair(stringOf(chunkAlphabet, 0, 6), stringOf(chunkAlphabet, 0, 6)), proc(p: (string, string)): bool {.raises: [CatchableError].} =
    let typed = newDraft().write(p[0])
    let rec = typed.store
    let written = rec.writeStored(p[1])
    let published = rec.publishStored
    let again = published.value.publishStored
    written.isOk and written.value == typed.write(p[1]).store and
      published.isOk and published.value == typed.publish.store and
      published.value.asPublished.isOk and
      again.isErr and again.error == seNotDraft and
      published.value.writeStored(p[1]).error == seNotDraft)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-TYPESTATE-07
test "FP-TYPESTATE-07 Given a move-only handle, when the draft is used after publish, then it does not compile, and the module's Result cannot carry one":
  const handle = """
type
  Draft = object
  Published = object
  Handle[S] {.requiresInit.} = object
    data: string
proc `=copy`[S](dst: var Handle[S]; src: Handle[S]) {.error.}
func publish(h: sink Handle[Draft]): Handle[Published] {.raises: [].} =
  Handle[Published](data: h.data)
"""
  let once = compileOutcome(handle & """
proc run(): string =
  let d = Handle[Draft](data: "x")
  let p = publish(d)
  p.data
doAssert run() == "x"
""")
  checkpoint once.output
  check once.exitCode == 0
  let twice = compileOutcome(handle & """
proc run(): string =
  let d = Handle[Draft](data: "x")
  let p = publish(d)
  let q = publish(d)
  p.data & q.data
doAssert run() == "xx"
""")
  check twice.exitCode != 0
  check "is not available" in twice.output
  # Without the `=copy` error the same reuse compiles: the copyable `Blob` does not stop it.
  let copyable = compileOutcome("""
import nimcs/fp/typestate
proc run(): string =
  let d = newDraft().write("x")
  let p = d.publish
  let q = d.publish
  p.read & q.read
doAssert run() == "xx"
""")
  checkpoint copyable.output
  check copyable.exitCode == 0
  let viaResult = compileOutcome(handle & """
import nimcs/fp/result
func make(): Result[Handle[Draft], string] {.raises: [].} =
  ok(Handle[Draft](data: "x"), string)
doAssert make().isOk
""")
  check viaResult.exitCode != 0

# SPEC: FP-TYPESTATE-08
test "FP-TYPESTATE-08 Given the state tags, when sizes are compared, then a typed blob is as large as its bytes":
  check sizeof(Blob[Draft]) == sizeof(string)
  check sizeof(Blob[Published]) == sizeof(string)
  check sizeof(Blob[Draft]) == sizeof(Blob[Published])
