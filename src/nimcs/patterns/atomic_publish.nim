## Atomic publish: write to a temporary name, flush, rename onto the visible name, flush the directory.
##
## A reader of the visible name must see the old content or the new content, never half of it, even
## if the machine stops at any instant. Writing in place cannot promise that; this protocol can,
## because `rename` within one directory replaces a name in one step and the file it names was made
## durable first. The protocol is five steps: create a temporary file with a unique name in the
## target's directory, write it, fsync the file, rename it onto the visible name, fsync the directory.
##
## The core models a directory as a value, `Disk`: a volatile view (what readers see, the page cache)
## and a durable view (what survives a crash). `publishPlan` gives the protocol as a list of `Step`s,
## `apply` runs one step on a `Disk`, and `crash` gives the state after a stop, where the machine
## picks the worst: unflushed bytes may be cut anywhere (`torn`) and a rename that no directory fsync
## followed may be lost (`fate`). Everything here is a `func`, so a test can stop the protocol
## after any step and ask what a reader finds. `SyncMode` removes the fsyncs, and a test shows that
## the law then fails: that is what they are for.
##
## The edge is one `proc`, `publishFile`, which makes the same plan and executes it on disk with
## `std/posix`. A visible name that is the hash of the content (`addressedName`) makes publishing
## idempotent by construction and lets a reader check what it read.

import std/[options, tables, strutils, algorithm, monotimes, os]
when defined(posix):
  import std/posix
import nimcs/fp/result

const
  TmpPrefix* = ".atomic-tmp-"
    ## Every temporary name starts with it, so what a crash leaves behind is recognised by name.

type
  SyncMode* = enum
    smFull      ## fsync the file, rename, fsync the directory: atomic and durable
    smFileOnly  ## no directory fsync: atomic, but the new content may be lost by a crash
    smNone      ## no fsync at all: a crash can leave the visible name empty or cut

  StepKind* = enum
    skCreate, skWrite, skFsyncFile, skRename, skFsyncDir

  Step* = object
    ## One operation of the protocol. `name` is the temporary name; `target` is where a rename
    ## puts it; `data` is what a write writes. Fields that a kind does not use are empty.
    kind*: StepKind
    name*: string
    target*: string
    data*: string

  PublishError* = enum
    peBadTarget, peBadToken, peDirMissing, peCreate, peWrite, peFsync, peRename, peFsyncDir,
    peFailedAndLeftover,  ## a step failed and the temporary file or descriptor could not be released
    peUnsupported

  DirFate* = enum
    dcKept  ## the directory as readers saw it survives, a rename not yet flushed included
    dcLost  ## only the durable directory survives: a rename no directory fsync followed is undone

  Inode = object
    cache: string   ## what readers see
    flushed: int    ## how many leading bytes are on the disk

  Disk* = object
    ## A directory as a value. Opaque: built with `emptyDisk` and `seeded`, changed by `apply`.
    inodes: seq[Inode]
    dir: Table[string, int]         ## names readers see
    durableDir: Table[string, int]  ## names that survive a crash

func emptyDisk*(): Disk {.raises: [].} =
  ## A directory with no file.
  Disk()

func seeded*(d: Disk; name, content: string): Disk {.raises: [].} =
  ## The directory with a file that is already fully on the disk, as one left by an earlier run.
  result = d
  result.inodes.add Inode(cache: content, flushed: content.len)
  result.dir[name] = result.inodes.high
  result.durableDir[name] = result.inodes.high

func isTemp*(name: string): bool {.raises: [].} =
  ## Whether a name is one this protocol made for a temporary file.
  name.startsWith(TmpPrefix)

func tmpName*(target, token: string): string {.raises: [].} =
  ## The temporary name for `target`: in the same directory (it has no separator), unique per token.
  TmpPrefix & token & "-" & target

func plainName(s: string): bool {.raises: [].} =
  s.len > 0 and s.len <= 200 and '/' notin s and '\0' notin s and s != "." and s != ".."

func publishPlan*(target, token, content: string; mode: SyncMode): Result[seq[Step], PublishError] {.raises: [].} =
  ## The steps that publish `content` as `target`. The target must be a plain name that does not
  ## look like a temporary one; the token (a process id and a counter, say) must be a plain name
  ## and differ between two publications to the same target that may overlap.
  if not plainName(target) or isTemp(target): return err(seq[Step], peBadTarget)
  if not plainName(token): return err(seq[Step], peBadToken)
  let tmp = tmpName(target, token)
  var steps = @[Step(kind: skCreate, name: tmp), Step(kind: skWrite, name: tmp, data: content)]
  if mode != smNone: steps.add Step(kind: skFsyncFile, name: tmp)
  steps.add Step(kind: skRename, name: tmp, target: target)
  if mode == smFull: steps.add Step(kind: skFsyncDir)
  ok(steps, PublishError)

func apply*(d: Disk; s: Step): Disk {.raises: [].} =
  ## What one step does to the volatile view, and to the durable one when it is an fsync.
  result = d
  case s.kind
  of skCreate:
    if s.name notin result.dir:
      result.inodes.add Inode(cache: "", flushed: 0)
      result.dir[s.name] = result.inodes.high
  of skWrite:
    let id = result.dir.getOrDefault(s.name, -1)
    if id >= 0: result.inodes[id].cache = s.data
  of skFsyncFile:
    let id = result.dir.getOrDefault(s.name, -1)
    if id >= 0: result.inodes[id].flushed = result.inodes[id].cache.len
  of skRename:
    let id = result.dir.getOrDefault(s.name, -1)
    if id >= 0:
      result.dir.del s.name
      result.dir[s.target] = id
  of skFsyncDir:
    result.durableDir = result.dir

func runSteps*(d: Disk; steps: seq[Step]; upTo: int): Disk {.raises: [].} =
  ## The state after the first `upTo` steps (all of them when it is larger).
  result = d
  for i in 0 ..< min(max(upTo, 0), steps.len): result = result.apply(steps[i])

func crash*(d: Disk; torn: int; fate: DirFate): Disk {.raises: [].} =
  ## The state after the machine stops and starts again. Of the bytes not yet flushed, `torn` leading
  ## ones reached the disk; and `fate` says which directory survived. A test chooses both, so it can pick the worst case.
  let extra = max(torn, 0)
  result.dir = if fate == dcKept: d.dir else: d.durableDir
  result.durableDir = result.dir
  for ino in d.inodes:
    let n = min(ino.cache.len, ino.flushed + extra)
    result.inodes.add Inode(cache: ino.cache[0 ..< n], flushed: n)

func read*(d: Disk; name: string): Option[string] {.raises: [].} =
  ## What a reader of `name` gets: its whole content, or none when there is no such name.
  let id = d.dir.getOrDefault(name, -1)
  if id < 0: none(string) else: some(d.inodes[id].cache)

func names*(d: Disk): seq[string] {.raises: [].} =
  ## The visible names, sorted.
  for name in d.dir.keys: result.add name
  result.sort()

func snapshot*(d: Disk): seq[(string, string)] {.raises: [].} =
  ## Every visible name with its content, sorted by name.
  for name in d.names: result.add (name, d.inodes[d.dir.getOrDefault(name, -1)].cache)

func leftovers*(d: Disk): seq[string] {.raises: [].} =
  ## The temporary files a stop left behind, recognised by their prefix.
  for name in d.names:
    if isTemp(name): result.add name

func cleanup*(d: Disk): Disk {.raises: [].} =
  ## The directory without the temporary files, and without anything else changed. The removal is
  ## durable: a real cleanup unlinks the files and then fsyncs the directory.
  result = d
  for name in d.leftovers:
    result.dir.del name
    result.durableDir.del name

func addressedName*(content: string): string {.raises: [].} =
  ## A name that is a function of the content alone: FNV-1a over 64 bits, as 16 hex digits.
  ## A real store uses a cryptographic hash (SHA-256); this one keeps the module free of packages.
  var h = 14695981039346656037'u64
  for c in content: h = (h xor uint64(ord(c))) * 1099511628211'u64
  result = "sum-"
  for i in 0 ..< 16: result.add "0123456789abcdef"[int((h shr uint64(60 - 4 * i)) and 15'u64)]

func verifies*(name, content: string): bool {.raises: [].} =
  ## Whether `content` is what `name` says it is: a reader's check of what it read.
  addressedName(content) == name

func planAddressed*(content, token: string; mode: SyncMode): Result[seq[Step], PublishError] {.raises: [].} =
  ## The plan that publishes `content` under its own hash.
  publishPlan(addressedName(content), token, content, mode)

when defined(posix):
  proc cRename(oldPath, newPath: cstring): cint {.importc: "rename", header: "<stdio.h>", raises: [].}
    ## rename(2) as the C library has it: atomic when both names are in one directory.

  proc syncFd(fd: cint): bool {.raises: [].} =
    while fsync(fd) != 0:
      if errno != EINTR: return false
    true

  proc writeAll(fd: cint; data: string): bool {.raises: [].} =
    var off = 0
    while off < data.len:
      let rest = data[off ..< data.len]
      let n = write(fd, cstring(rest), rest.len)
      if n < 0:
        if errno == EINTR: continue
        return false
      if n == 0: return false
      off += n
    true

  proc abort(fd: cint; tmpPath: string; tmpExists: bool; why: PublishError): PublishError {.raises: [].} =
    ## The error to report once a step failed: the descriptor is closed and the temporary file removed.
    ## If the descriptor cannot be closed or the file cannot be removed, something stays behind and
    ## the error says so; a file left behind is recognised by its prefix.
    if fd >= 0 and close(fd) != 0: return peFailedAndLeftover
    if tmpExists and unlink(cstring(tmpPath)) != 0 and errno != ENOENT: return peFailedAndLeftover
    why

  proc publishFile*(dir, target, content: string; mode: SyncMode = smFull): Result[string, PublishError] {.raises: [].} =
    ## The edge: publish `content` as `dir/target`, executing `publishPlan` with `std/posix`. The
    ## temporary file is created in `dir` with O_EXCL, so two writers never share one. No exception
    ## escapes; a failed step removes the temporary file and says which step failed. After
    ## `peFsyncDir` the new content is visible but not yet known to be durable.
    let token = $getCurrentProcessId() & "-" & $getMonoTime().ticks
    let plan = publishPlan(target, token, content, mode)
    if plan.isErr: return err(string, plan.error)
    var fd = cint(-1)
    var tmpPath = ""
    for s in plan.value:
      case s.kind
      of skCreate:
        tmpPath = dir / s.name
        fd = open(cstring(tmpPath), O_WRONLY or O_CREAT or O_EXCL, Mode(0o644))
        if fd < 0:
          let why = if errno == ENOENT or errno == ENOTDIR: peDirMissing else: peCreate
          return err(string, why)
      of skWrite:
        if not writeAll(fd, s.data): return err(string, abort(fd, tmpPath, true, peWrite))
      of skFsyncFile:
        if not syncFd(fd): return err(string, abort(fd, tmpPath, true, peFsync))
      of skRename:
        if close(fd) != 0:
          fd = cint(-1)
          return err(string, abort(fd, tmpPath, true, peWrite))
        fd = cint(-1)
        if cRename(cstring(tmpPath), cstring(dir / s.target)) != 0:
          return err(string, abort(fd, tmpPath, true, peRename))
      of skFsyncDir:
        let dfd = open(cstring(dir), O_RDONLY)
        if dfd < 0: return err(string, peFsyncDir)
        if not syncFd(dfd):
          return err(string, abort(dfd, "", false, peFsyncDir))
        if close(dfd) != 0: return err(string, peFsyncDir)
    ok(dir / target, PublishError)
else:
  proc publishFile*(dir, target, content: string; mode: SyncMode = smFull): Result[string, PublishError] {.raises: [].} =
    ## This platform has no `std/posix`; see the page for what Windows needs instead.
    err(string, peUnsupported)
