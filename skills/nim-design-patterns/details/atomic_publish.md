# Atomic publish (temporary name, fsync, rename, fsync the directory)

## Intent
Replace a file so that a reader sees the old content or the new content, never a part of it, and so that this still holds if the machine stops at any instant. Write the new content under a temporary name in the same directory, flush it to the disk, rename it onto the visible name, then flush the directory. The rename is the only moment the visible name changes; before it the reader has the old file, after it the new one.

## Use when / avoid when
- Use for a file that others read while you replace it: a configuration, an index, a manifest, a cache entry, a downloaded artifact that a build reads.
- Use when a crash in the middle must not leave the visible name empty or cut; a program that restarts and finds a half-written config has lost more than the write.
- Use with `idempotent_command.md`: publishing the same content again changes nothing, so a retried command is safe.
- Use a name that is the hash of the content (see Nim shape) when the same content may be published many times or by many writers; the name then says what the file must contain.
- Avoid it for a file that is appended to in place, such as a log or a journal. Appending cannot be done by renaming; use an append-only file with a checksum per record (`event_sourcing.md`).
- Avoid it across directories on different file systems: `rename` is atomic only inside one file system, so the temporary file must be made in the target's directory, never in `/tmp`.
- Avoid it when the data may be lost by design (a cache that is rebuilt on a miss): the two fsyncs cost milliseconds each, and `smNone` or a plain write is enough.

## Nim shape
The module is `src/nimcs/patterns/atomic_publish.nim`. The core is a directory as a value, `Disk`: a volatile view that readers see and a durable view that survives a crash. `publishPlan` gives the protocol as a list of `Step`s (`skCreate`, `skWrite`, `skFsyncFile`, `skRename`, `skFsyncDir`), `apply` runs one step, `runSteps` runs the first k, and `crash` gives the state after a stop. A stop is chosen by the test and is as bad as allowed: `torn` leading bytes of the unflushed data reached the disk, and `DirFate` says whether a rename that no directory fsync followed survived (`dcKept`) or was undone (`dcLost`). Every one of these is a `func`.

```nim
import std/options
import nimcs/fp/result
import nimcs/patterns/atomic_publish

let before = emptyDisk().seeded("page", "old")
let plan = publishPlan("page", "t1", "new", smFull).value
# a reader at every step sees the old content until the rename, the new content from it
doAssert before.runSteps(plan, 3).read("page") == some("old")    # created, written, fsynced
doAssert before.runSteps(plan, 4).read("page") == some("new")    # renamed
# a crash anywhere, with the worst torn write and the rename lost: still old or new
for k in 0 .. plan.len:
  let seen = before.runSteps(plan, k).crash(0, dcLost).read("page")
  doAssert seen == some("old") or seen == some("new")
```

`SyncMode` removes the fsyncs, and the same law then fails; this is what the fsyncs are for. Without the directory fsync (`smFileOnly`) the visible name is still old or new, but a finished publish may be lost by a crash. Without any fsync (`smNone`) a crash after the rename can leave the visible name empty or cut:

```nim
import std/options
import nimcs/fp/result
import nimcs/patterns/atomic_publish

let before = emptyDisk().seeded("page", "old")
let noSync = publishPlan("page", "t1", "new", smNone).value        # create, write, rename
# the rename reached the directory, only 2 of the 3 bytes reached the file
doAssert before.runSteps(noSync, 3).crash(2, dcKept).read("page") == some("ne")
let fileOnly = publishPlan("page", "t1", "new", smFileOnly).value
# finished, but the directory was not flushed: the crash brings the old file back
doAssert before.runSteps(fileOnly, 4).crash(0, dcLost).read("page") == some("old")
```

What a stop leaves behind is a temporary file. Its name starts with `TmpPrefix`, so `leftovers` finds exactly those and `cleanup` removes exactly those:

```nim
import nimcs/fp/result
import nimcs/patterns/atomic_publish

let plan = publishPlan("page", "t1", "new", smFull).value
let stopped = emptyDisk().runSteps(plan, 2).crash(0, dcKept)          # created and written, then stop
doAssert stopped.leftovers == @[tmpName("page", "t1")]
doAssert stopped.cleanup.names.len == 0
```

The edge is one `proc`, `publishFile`. It makes the same plan and executes it with `std/posix`: `open` with `O_EXCL` in the target's directory, `write` until everything is written, `fsync`, `rename` (the C library's, atomic inside one directory), then `open` the directory and `fsync` it. It returns a `Result` with the path or a `PublishError` that names the failed step; a failed step removes the temporary file; no exception escapes.

```nim
import std/os
import nimcs/fp/result
import nimcs/patterns/atomic_publish

let dir = getTempDir()
let published = publishFile(dir, "atomic-publish-example.txt", "hello")
doAssert published.isOk
doAssert readFile(published.value) == "hello"
removeFile(published.value)
doAssert publishFile(dir / "no-such-dir", "x", "y") == err(string, peDirMissing)
```

When the content can name itself, the visible name is its hash. `planAddressed` publishes under `addressedName(content)`: publishing the same content twice finds the file already there with the same bytes, two writers of the same content do not disturb each other, and a reader checks what it read with `verifies(name, content)`: a cut file under a hash name is detected, not trusted. The module's hash is FNV-1a over 64 bits to stay free of packages; a store that must resist a chosen collision uses SHA-256.

```nim
import std/options
import nimcs/fp/result
import nimcs/patterns/atomic_publish

let name = addressedName("hello")
let plan = planAddressed("hello", "t1", smNone).value
let cut = emptyDisk().runSteps(plan, 3).crash(2, dcKept)             # no fsync: a cut file is visible
doAssert cut.read(name) == some("he")
doAssert not verifies(name, "he")                                  # and the reader sees it is cut
doAssert verifies(name, "hello")
```

On Windows the same shape needs different calls and one step less. `std/posix` does not exist there, so `publishFile` returns `peUnsupported`; a Windows edge would write the temporary file, flush it (`FlushFileBuffers`), and replace the name with `MoveFileExW` and `MOVEFILE_REPLACE_EXISTING` (without `MOVEFILE_COPY_ALLOWED`, which would turn a cross-volume move into a copy and give up atomicity), or use `ReplaceFileW`. There is no directory fsync: a directory cannot be opened for flushing, and NTFS journals its metadata. The core and the plan do not change; only the interpreter of the steps does. This page did not run on Windows. On macOS, `fsync` does not ask the drive to empty its own cache; a program that needs that calls `fcntl(fd, F_FULLFSYNC)`, which this module does not.

## Public API

Every exported symbol of `src/nimcs/patterns/atomic_publish.nim`, generated by `nim apiSections` (the
tests fail when it drifts). `import nimcs/patterns/atomic_publish` brings these names. A type they use from
another module (`Option`, `Result`, `Graph`) needs that module's import too, as in the example
above. A field marked `*` is readable outside the module; a type shown without fields is opaque,
built and read only through the functions.

```text
const TmpPrefix = ".atomic-tmp-"
type SyncMode = enum
  smFull,                   ## fsync the file, rename, fsync the directory: atomic and durable
  smFileOnly,               ## no directory fsync: atomic, but the new content may be lost by a crash
  smNone                     ## no fsync at all: a crash can leave the visible name empty or cut
type StepKind = enum
  skCreate, skWrite, skFsyncFile, skRename, skFsyncDir
type Step = object
  kind*: StepKind
  name*: string
  target*: string
  data*: string
type PublishError = enum
  peBadTarget, peBadToken, peDirMissing, peCreate, peWrite, peFsync, peRename,
  peFsyncDir, peFailedAndLeftover, ## a step failed and the temporary file or descriptor could not be released
  peUnsupported
type DirFate = enum
  dcKept,                   ## the directory as readers saw it survives, a rename not yet flushed included
  dcLost                     ## only the durable directory survives: a rename no directory fsync followed is undone
type Disk = object
func emptyDisk(): Disk
func seeded(d: Disk; name, content: string): Disk
func isTemp(name: string): bool
func tmpName(target, token: string): string
func publishPlan(target, token, content: string; mode: SyncMode): Result[seq[Step], PublishError]
func apply(d: Disk; s: Step): Disk
func runSteps(d: Disk; steps: seq[Step]; upTo: int): Disk
func crash(d: Disk; torn: int; fate: DirFate): Disk
func read(d: Disk; name: string): Option[string]
func names(d: Disk): seq[string]
func snapshot(d: Disk): seq[(string, string)]
func leftovers(d: Disk): seq[string]
func cleanup(d: Disk): Disk
func addressedName(content: string): string
func verifies(name, content: string): bool
func planAddressed(content, token: string; mode: SyncMode): Result[seq[Step], PublishError]
proc publishFile(dir, target, content: string; mode: SyncMode = smFull): Result[string, PublishError]
```

## Laws and invariants
Why this is testable: the protocol is a list of values and the disk is a value, so a property can stop it after any step with the worst torn write and the worst lost rename.
- A stop at any step, with any torn write and any lost rename, leaves the visible name with exactly the old or exactly the new content (PAT-ATOMICPUBLISH-01).
- A reader during the protocol sees the old content until the rename and the new content from it, and never the temporary name (PAT-ATOMICPUBLISH-02).
- After a finished full publish any crash keeps the new content; without the directory fsync it can be lost, without any fsync the name can be empty or cut (PAT-ATOMICPUBLISH-03).
- Leftovers are exactly the prefixed names, and `cleanup` removes exactly them (PAT-ATOMICPUBLISH-04).
- Publishing the same content twice equals publishing it once (PAT-ATOMICPUBLISH-05).
- The plan is in protocol order, in one directory, unique per token, and refuses bad names (PAT-ATOMICPUBLISH-06).
- Under a hash name any visible file verifies, and a cut one does not (PAT-ATOMICPUBLISH-07).
- The disk edge leaves exactly the content and no temporary file, and reports errors as values (PAT-ATOMICPUBLISH-08).

The model assumes what POSIX file systems promise in practice: `rename` within one directory replaces a name in one step, `fsync` on a file makes its bytes durable, and `fsync` on a directory makes its entries durable. It does not model a disk that lies about flushing, or a file system that reorders a rename ahead of the data it names without an fsync in between (that is what `smNone` shows).

## Complexity
Time: O(n) in the content length for the write, plus two fsyncs, which dominate (milliseconds on a disk). The model's `apply` copies the directory value: O(files). Space: the content once more on disk until the rename.

## Pitfalls
Writing in place, putting the temporary file elsewhere, and forgetting the flushes:

```nim bad
import std/os

proc save(path, content: string) =
  writeFile(path, content)                         # in place: truncated at once, a crash leaves it empty or cut
                                                   # and a reader sees the file half written

proc saveViaTmp(path, content: string) =
  let tmp = getTempDir() / "page.tmp"              # another directory, often another file system
  writeFile(tmp, content)                          # no fsync: the rename can reach the disk before the bytes
  moveFile(tmp, path)                              # across file systems this is copy and delete, not atomic
                                                   # and no directory fsync: the rename can be lost
```

Fix: `publishFile`, or the same steps in your own edge: a unique temporary name in the target's directory, `fsync` the file, `rename`, `fsync` the directory.

- Writing in place: `open` with truncation empties the file before the first byte of the new content is written.
- Renaming across file systems: `rename` fails with `EXDEV`, and a library's `moveFile` falls back to copy and delete, which a reader can see half done. Keep the temporary file in the target's directory.
- Forgetting the directory fsync: the new file is complete and the visible name is old or new, but a crash right after a "successful" publish can bring the old content back, and a caller that reported success was wrong.
- A policy that lets the writer keep writing after the publish: the writer's handle still names the file that is now visible, so a later write changes the published content in place. Close the temporary file before the rename and never hand its handle on.
- A temporary name that two writers can share (a fixed `page.tmp`): they overwrite each other's bytes. Make it unique, and create it with `O_EXCL` so a collision is an error and not a shared file.
- Leaving crash leftovers: run `cleanup` on start, or delete names with `TmpPrefix` older than any running writer; do not delete one a live writer may still be using.

## Related
- `idempotent_command.md` (publishing the same content again changes nothing)
- `event_sourcing.md` (the append-only alternative to replacing a file)
- `functional_core.md` (the plan and the disk model are the core, `publishFile` is the shell)
- `retry_backoff.md` (a failed publish is safe to retry: it left the old file and no temporary file)
- `merkle_tree` in nim-data-structures (content-addressed names generalised to a tree of hashes)

## Sources

None in the catalog: no source in catalog/sources.jsonl was found whose title or listed contents covers crash consistency, fsync or atomic rename (searched 2026-11-21 by title for operating system, file system, crash, durab, storage, unix and rename; the one operating-systems textbook, Operating Systems: Three Easy Pieces, 24c2ca14b8ed5bf2, lists no contents in the catalog, so the page does not cite it); the page cites no source it has not read.
