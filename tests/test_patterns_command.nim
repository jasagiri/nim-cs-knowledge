import std/[unittest, unicode]
import propcheck
import nimcs/fp/result
import nimcs/patterns/command

# A command is generated as (isInsert, position, length-or-text-seed); positions may be out of range.
type Raw = ((bool, int), (int, string))

func toCmd(r: Raw): Cmd {.raises: [].} =
  if r[0][0]: insertCmd(r[0][1], r[1][1]) else: deleteCmd(r[0][1], r[1][0])

func rawGen(): Gen[Raw] {.raises: [ValueError].} =
  pair(pair(boolean(), intIn(-1, 14)), pair(intIn(-1, 6), stringOf("abc", 0, 4)))

func base(): string {.raises: [].} = "hello world"

# SPEC: GOF-COMMAND-01
test "GOF-COMMAND-01 Given any valid command, when executed and then undone, then the text is the original":
  let outcome = check(rawGen(), proc(r: Raw): bool {.raises: [CatchableError].} =
    let ed = initEditor(base())
    let after = ed.exec(toCmd(r))
    if after.isErr: return true   # invalid commands are covered by GOF-COMMAND-02
    let back = after.value.undo
    back.isOk and back.value.text == base())
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-COMMAND-02
test "GOF-COMMAND-02 Given an out-of-range command, when executed, then it fails with eeOutOfRange":
  let ed = initEditor("abc")
  check ed.exec(insertCmd(4, "x")).error == eeOutOfRange
  check ed.exec(insertCmd(-1, "x")).error == eeOutOfRange
  check ed.exec(deleteCmd(2, 2)).error == eeOutOfRange
  check ed.exec(deleteCmd(0, -1)).error == eeOutOfRange

# SPEC: GOF-COMMAND-02
test "GOF-COMMAND-02 Given any command, when it fails, then the same editor value still works":
  let outcome = check(rawGen(), proc(r: Raw): bool {.raises: [CatchableError].} =
    let ed = initEditor(base())
    let a = ed.exec(toCmd(r))
    let b = ed.exec(toCmd(r))
    a == b and (a.isOk or ed == initEditor(base())))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-COMMAND-03
test "GOF-COMMAND-03 Given a command log, when replayed twice, then both runs agree":
  let outcome = check(seqOf(rawGen(), 0, 8), proc(rs: seq[Raw]): bool {.raises: [CatchableError].} =
    var log: seq[Cmd]
    for r in rs: log.add toCmd(r)
    replay(base(), log) == replay(base(), log))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-COMMAND-03
test "GOF-COMMAND-03 Given a valid log, when replayed by apply one at a time and by exec, then the texts agree":
  let outcome = check(seqOf(rawGen(), 0, 8), proc(rs: seq[Raw]): bool {.raises: [CatchableError].} =
    var log: seq[Cmd]
    for r in rs: log.add toCmd(r)
    let replayed = replay(base(), log)
    var ed = initEditor(base())
    var failed = false
    for c in log:
      let n = ed.exec(c)
      if n.isErr:
        failed = true
        break
      ed = n.value
    if failed: replayed.isErr else: replayed.isOk and replayed.value == ed.text)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-COMMAND-04
test "GOF-COMMAND-04 Given a sequence of edits, when all are undone, then the original text returns":
  let outcome = check(seqOf(rawGen(), 0, 8), proc(rs: seq[Raw]): bool {.raises: [CatchableError].} =
    var ed = initEditor(base())
    var done = 0
    for r in rs:
      let n = ed.exec(toCmd(r))
      if n.isOk:
        ed = n.value
        inc done
    for _ in 0 ..< done:
      let u = ed.undo
      if u.isErr: return false
      ed = u.value
    ed.text == base() and ed.undoStack.len == 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-COMMAND-05
test "GOF-COMMAND-05 Given an undone edit, when redone, then the text equals the text after the edit":
  let outcome = check(rawGen(), proc(r: Raw): bool {.raises: [CatchableError].} =
    let after = initEditor(base()).exec(toCmd(r))
    if after.isErr: return true
    let round = after.value.undo.value.redo
    round.isOk and round.value.text == after.value.text and round.value == after.value)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-COMMAND-06
test "GOF-COMMAND-06 Given an undone edit, when a new command executes, then redo is no longer possible":
  let a = initEditor("ab").exec(insertCmd(1, "X")).value.undo.value
  check a.redoStack.len == 1
  let b = a.exec(insertCmd(0, "Y")).value
  check b.redoStack.len == 0
  check b.redo.error == eeNothingToRedo

# SPEC: GOF-COMMAND-07
test "GOF-COMMAND-07 Given a fresh editor, when undo is requested, then it fails with eeNothingToUndo":
  check initEditor("abc").undo.error == eeNothingToUndo

# SPEC: GOF-COMMAND-08
test "GOF-COMMAND-08 Given the document hello world, when concrete edits run, then the texts are as written":
  let ed = initEditor("hello world")
  let e1 = ed.exec(deleteCmd(5, 6)).value
  check e1.text == "hello"
  let e2 = e1.exec(insertCmd(5, "!")).value
  check e2.text == "hello!"
  check e2.undo.value.undo.value.text == "hello world"

# SPEC: GOF-COMMAND-09
test "GOF-COMMAND-09 Given a multi-byte document, when commands cut inside a character or insert invalid UTF-8, then they fail and valid text stays valid":
  let doc = "h\xC3\xA9llo \xE6\x97\xA5\xE6\x9C\xAC"   # "héllo 日本": 13 bytes, é is 2 bytes, each kanji 3
  let ed = initEditor(doc)
  check ed.exec(insertCmd(2, "x")).error == eeNotCharBoundary     # inside é
  check ed.exec(insertCmd(8, "x")).error == eeNotCharBoundary     # inside 日
  check ed.exec(deleteCmd(1, 1)).error == eeNotCharBoundary       # ends inside é
  check ed.exec(deleteCmd(2, 2)).error == eeNotCharBoundary       # starts inside é
  check ed.exec(insertCmd(0, "\xC3")).error == eeInvalidUtf8      # lone lead byte
  check ed.exec(insertCmd(0, "\xFF")).error == eeInvalidUtf8
  check ed.exec(deleteCmd(1, 2)).value.text == "hllo \xE6\x97\xA5\xE6\x9C\xAC"
  let snippets = ["", "a", "\xC3\xA9", "\xE6\x97\xA5\xE6\x9C\xAC", "xyz", "\xF0\x9F\x98\x80"]
  let outcome = check(seqOf(pair(pair(boolean(), intIn(-1, 16)), pair(intIn(-1, 8), intIn(0, 5))), 0, 8),
    proc(rs: seq[((bool, int), (int, int))]): bool {.raises: [CatchableError].} =
      var e = initEditor(doc)
      var applied = 0
      for r in rs:
        let c = if r[0][0]: insertCmd(r[0][1], snippets[r[1][1]]) else: deleteCmd(r[0][1], r[1][0])
        let n = e.exec(c)
        if n.isOk:
          e = n.value
          inc applied
          if validateUtf8(e.text) != -1: return false
      for _ in 0 ..< applied:
        e = e.undo.value
      e.text == doc)
  checkpoint describe(outcome)
  check outcome.passed
