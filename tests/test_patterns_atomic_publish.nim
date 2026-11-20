import std/[unittest, options, os, strutils, monotimes]
import propcheck
import nimcs/fp/result
import nimcs/patterns/atomic_publish

const target = "page"

func setup(hasOld: bool; old: string): Disk {.raises: [].} =
  if hasOld: emptyDisk().seeded(target, old) else: emptyDisk()

func fate(keep: bool): DirFate {.raises: [].} = (if keep: dcKept else: dcLost)

func oldOf(hasOld: bool; old: string): Option[string] {.raises: [].} =
  if hasOld: some(old) else: none(string)

func planOf(content: string; mode: SyncMode; token = "t1"): seq[Step] {.raises: [].} =
  let p = publishPlan(target, token, content, mode)
  doAssert p.isOk
  p.value

func publishAll(d: Disk; content: string; token: string; mode = smFull): Disk {.raises: [].} =
  d.runSteps(planOf(content, mode, token), 99)

func contentGen(): Gen[string] {.raises: [].} =
  try: stringOf("abc", 0, 12) except ValueError: raise newException(Defect, "bad generator range")

# the old state (present or not, with its content), the new content, how far the protocol got, how
# much unflushed data reached the disk, and whether the unflushed rename survived
type Case = (((bool, string), string), ((int, int), bool))

func caseGen(): Gen[Case] {.raises: [].} =
  try:
    pair(pair(pair(boolean(), contentGen()), contentGen()), pair(pair(intIn(0, 5), intIn(0, 14)), boolean()))
  except ValueError: raise newException(Defect, "bad generator range")

# SPEC: PAT-ATOMICPUBLISH-01
test "PAT-ATOMICPUBLISH-01 Given any old content, new content, crash point, torn write and lost rename, when the protocol was stopped, then the visible name holds exactly the old or exactly the new content":
  let outcome = check(caseGen(), proc(x: Case): bool {.raises: [CatchableError].} =
    let (((hasOld, old), nw), ((k, torn), keep)) = x
    var holds = true
    for mode in [smFull, smFileOnly]:
      let after = setup(hasOld, old).runSteps(planOf(nw, mode), k).crash(torn, fate(keep))
      let seen = after.read(target)
      holds = holds and (seen == oldOf(hasOld, old) or seen == some(nw))
    holds)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-ATOMICPUBLISH-02
test "PAT-ATOMICPUBLISH-02 Given a reader during the protocol and no crash, when the plan has run k steps, then the visible name holds the old content until the rename and the new content from it, and the temporary file is never the visible name":
  let outcome = check(caseGen(), proc(x: Case): bool {.raises: [CatchableError].} =
    let (((hasOld, old), nw), ((k, _), _)) = x
    let plan = planOf(nw, smFull)
    let seen = setup(hasOld, old).runSteps(plan, k).read(target)
    var renamed = false
    for i in 0 ..< min(k, plan.len):
      if plan[i].kind == skRename: renamed = true
    let tmp = plan[0].name
    let tmpIsTarget = tmp == target
    (if renamed: seen == some(nw) else: seen == oldOf(hasOld, old)) and not tmpIsTarget and isTemp(tmp))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-ATOMICPUBLISH-03
test "PAT-ATOMICPUBLISH-03 Given a finished full publish, when the machine stops, then the new content survives; without the directory fsync it may be lost, and without any fsync the name may be empty":
  let outcome = check(caseGen(), proc(x: Case): bool {.raises: [CatchableError].} =
    let (((hasOld, old), nw), ((_, torn), keep)) = x
    setup(hasOld, old).publishAll(nw, "t1").crash(torn, fate(keep)).read(target) == some(nw))
  checkpoint describe(outcome)
  check outcome.passed
  # the witnesses: what the missing steps cost
  let before = setup(true, "old")
  check before.publishAll("new", "t1", smFileOnly).crash(0, dcLost).read(target) == some("old")
  check before.runSteps(planOf("new", smNone), 3).crash(0, dcKept).read(target) == some("")
  check before.runSteps(planOf("new", smNone), 3).crash(2, dcKept).read(target) == some("ne")
  # and the law fails for the variant without fsync, found by search, not by a chosen example
  let broken = check(caseGen(), proc(x: Case): bool {.raises: [CatchableError].} =
    let (((hasOld, old), nw), ((k, torn), keep)) = x
    let seen = setup(hasOld, old).runSteps(planOf(nw, smNone), k).crash(torn, fate(keep)).read(target)
    seen == oldOf(hasOld, old) or seen == some(nw))
  check not broken.passed

# SPEC: PAT-ATOMICPUBLISH-04
test "PAT-ATOMICPUBLISH-04 Given a stop at any step, when the directory is read, then the leftovers are exactly the names with the temporary prefix and cleanup removes exactly them":
  let outcome = check(caseGen(), proc(x: Case): bool {.raises: [CatchableError].} =
    let (((hasOld, old), nw), ((k, torn), keep)) = x
    let after = setup(hasOld, old).runSteps(planOf(nw, smFull), k).crash(torn, fate(keep))
    var temps: seq[string]
    var others: seq[(string, string)]
    for (name, body) in after.snapshot:
      if name.startsWith(TmpPrefix): temps.add name else: others.add (name, body)
    let cleaned = after.cleanup
    after.leftovers == temps and cleaned.snapshot == others and cleaned.leftovers.len == 0 and
      cleaned.cleanup.snapshot == cleaned.snapshot and
      (k < 5 or after.leftovers.len == 0))
  checkpoint describe(outcome)
  check outcome.passed
  let afterCreate = emptyDisk().runSteps(planOf("x", smFull), 1).crash(0, dcKept)
  check afterCreate.leftovers == @[tmpName(target, "t1")]
  check afterCreate.cleanup.names.len == 0

# SPEC: PAT-ATOMICPUBLISH-05
test "PAT-ATOMICPUBLISH-05 Given any directory and content, when the same content is published twice, then the directory is as after the first, and the second finds the first's file as old content":
  let outcome = check(caseGen(), proc(x: Case): bool {.raises: [CatchableError].} =
    let (((hasOld, old), nw), _) = x
    let once = setup(hasOld, old).publishAll(nw, "t1")
    let twice = once.publishAll(nw, "t2")
    twice.snapshot == once.snapshot and twice.read(target) == some(nw) and once.leftovers.len == 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-ATOMICPUBLISH-06
test "PAT-ATOMICPUBLISH-06 Given the three modes and some names, when a plan is made, then the steps are in protocol order, the temporary name is in the target's directory and unique per token, and bad names are refused":
  func kinds(mode: SyncMode): seq[StepKind] =
    for s in planOf("x", mode): result.add s.kind
  check kinds(smFull) == @[skCreate, skWrite, skFsyncFile, skRename, skFsyncDir]
  check kinds(smFileOnly) == @[skCreate, skWrite, skFsyncFile, skRename]
  check kinds(smNone) == @[skCreate, skWrite, skRename]
  check planOf("body", smFull)[1].data == "body"
  check planOf("body", smFull)[3].target == target
  check tmpName(target, "a") != tmpName(target, "b")
  check '/' notin tmpName(target, "a") and isTemp(tmpName(target, "a")) and not isTemp(target)
  for bad in ["", "a/b", ".", "..", TmpPrefix & "x", "x\0y"]:
    check publishPlan(bad, "t", "x", smFull) == err(seq[Step], peBadTarget)
  for bad in ["", "a/b", ".."]:
    check publishPlan(target, bad, "x", smFull) == err(seq[Step], peBadToken)

# SPEC: PAT-ATOMICPUBLISH-07
test "PAT-ATOMICPUBLISH-07 Given content published under its own hash, when the machine stops at any step, then a visible name always verifies against what it holds, a second publication changes nothing, and a cut file under a hash name is detected":
  let contentOf = proc(x: Case): string {.raises: [].} = x[0][1] & "z"   # never empty
  let outcome = check(caseGen(), proc(x: Case): bool {.raises: [CatchableError].} =
    let (_, ((k, torn), keep)) = x
    let content = contentOf(x)
    let name = addressedName(content)
    let plan = planAddressed(content, "t1", smFull).value
    let after = emptyDisk().runSteps(plan, k).crash(torn, fate(keep))
    let seen = after.read(name)
    let once = emptyDisk().runSteps(plan, 99)
    let twice = once.runSteps(planAddressed(content, "t2", smFull).value, 99)
    (seen.isNone or verifies(name, seen.get)) and twice.snapshot == once.snapshot)
  checkpoint describe(outcome)
  check outcome.passed
  check addressedName("a") == addressedName("a")
  check addressedName("a") != addressedName("b")
  check addressedName("").len == 20 and addressedName("").startsWith("sum-")
  let plan = planAddressed("hello", "t1", smNone).value
  let cut = emptyDisk().runSteps(plan, 3).crash(2, dcKept)
  check cut.read(addressedName("hello")) == some("he")
  check not verifies(addressedName("hello"), "he")
  check verifies(addressedName("hello"), "hello")
  # two contents, two names: publishing the second leaves the first
  let both = emptyDisk().publishAll("x", "t1").runSteps(planAddressed("y", "t2", smFull).value, 99)
  check both.names.len == 2

# SPEC: PAT-ATOMICPUBLISH-08
test "PAT-ATOMICPUBLISH-08 Given a directory on disk, when content is published, then the file holds exactly it, no temporary file remains, and a missing directory or a bad name is an error value":
  let work = getTempDir() / "nck-atomic-publish-" & $getCurrentProcessId() & "-" & $getMonoTime().ticks
  createDir(work)
  defer: removeDir(work)
  proc listing(): seq[string] =
    for kind, path in walkDir(work): result.add path.extractFilename
  for mode in [smFull, smFileOnly, smNone]:
    check publishFile(work, "page.txt", "first", mode) == ok(work / "page.txt", PublishError)
    check readFile(work / "page.txt") == "first"
    check publishFile(work, "page.txt", "second, longer", mode).isOk
    check readFile(work / "page.txt") == "second, longer"
    check listing() == @["page.txt"]
  check publishFile(work, "page.txt", "", smFull).isOk
  check readFile(work / "page.txt") == ""
  let big = repeat("0123456789abcdef", 65_536)   # 1 MiB: more than one pipe or buffer write
  check publishFile(work, "big.bin", big).isOk
  check readFile(work / "big.bin") == big
  check publishFile(work, "page.txt", "x") == ok(work / "page.txt", PublishError)
  check publishFile(work / "missing", "page.txt", "x") == err(string, peDirMissing)
  check publishFile(work, "../escape", "x") == err(string, peBadTarget)
  check publishFile(work, TmpPrefix & "x", "x") == err(string, peBadTarget)
  check listing().len == 2
