# Three-way merge (base, ours, theirs)

## Intent
Two parties edited the same original. Comparing only their two results cannot tell "A added this" from "B deleted this", but comparing each with the original (the base) can. Merge by deciding every part from its three versions: if only one side changed it, take that side; if both changed it the same way, take that; if both changed it differently, report a conflict as a value. It works at two levels: a map (a directory tree merged path by path, as a file sync service merges two generations) and a sequence (diff3, which aligns lines through the longest common subsequence).

## Use when / avoid when
- Use it whenever two copies diverged from a known common ancestor and no human is in the loop yet: sync services, version control, offline-first editors, configuration merged from two branches.
- Use the keyed merge when the unit of change is a key (a path, a field, an id) and the values are compared whole.
- Use the sequence merge when the unit is an ordered list of lines or items and edits at different places should combine.
- Avoid it without the base. Two versions alone give a two-way merge, which has to guess whether a missing item was added on one side or deleted on the other.
- Avoid "newest modification time wins" as a stand-in: it silently drops the other side's edit and depends on two machines' clocks agreeing.
- Avoid treating a clean merge as a correct one: it only means the edits did not overlap, not that the combination makes sense (two edits can each be fine and break together).

## Nim shape
The module is `src/nimcs/algo/three_way_merge.nim`. A map merge is `mergeKeyed(base, ours, theirs)` over `Table[string, V]` and returns a `KeyedMerge`, an object variant: clean with the merged map, or conflicted with the keys that need a decision (each a `KeyConflict` holding all three versions as `Option`, `none` meaning absent) and the keys already settled. Deletion is a change like any other.

```nim
import std/[options, tables]
import nimcs/algo/three_way_merge

let base = {"notes.txt": 1, "photo.png": 2, "todo.md": 3}.toTable
let ours = {"notes.txt": 10, "photo.png": 2, "todo.md": 3, "new.txt": 4}.toTable
let theirs = {"notes.txt": 1, "todo.md": 30}.toTable           # photo.png deleted, todo.md edited
let m = mergeKeyed(base, ours, theirs)
doAssert m.isClean
doAssert m.merged == {"notes.txt": 10, "todo.md": 30, "new.txt": 4}.toTable

# both sides edited todo.md differently; theirs also deleted photo.png, which ours left alone
let c = mergeKeyed(base, {"todo.md": 31, "notes.txt": 1, "photo.png": 2}.toTable,
                   {"todo.md": 32, "notes.txt": 1}.toTable)
doAssert not c.isClean
doAssert conflictKeys(c) == @["todo.md"]
doAssert c.resolved == {"notes.txt": 1}.toTable      # the deletion was taken, the rest unchanged
doAssert c.conflicts[0].key == "todo.md"
doAssert c.conflicts[0].base == some(3) and c.conflicts[0].ours == some(31) and c.conflicts[0].theirs == some(32)
```

The sequence merge `merge3(base, ours, theirs)` is generic over any element with `==`. It returns chunks: `Stable` lines all three still share, `Clean` lines taken from one side (or from both, when they changed it the same way; empty for a deletion), and `Conflict(base, ours, theirs)`. `mergeLines` gives the merged sequence when no conflict is open and `render` writes the usual conflict markers. Build chunks through `stable`, `clean` and `conflict`.

```nim
import std/options
import nimcs/algo/three_way_merge

let base = toLines("a\nb\nc\nd\ne\n")
let ours = toLines("a\nX\nc\nd\ne\n")
let theirs = toLines("a\nb\nc\nd\nY\n")
let merged = merge3(base, ours, theirs)
doAssert conflictCount(merged) == 0
doAssert mergeLines(merged) == some(toLines("a\nX\nc\nd\nY\n"))
doAssert merged == @[stable(@["a"]), clean(sOurs, @["X"]), stable(@["c", "d"]), clean(sTheirs, @["Y"])]

let both = merge3(toLines("a\nb\nc\n"), toLines("a\nX\nc\n"), toLines("a\nY\nc\n"))
doAssert conflictCount(both) == 1
doAssert mergeLines(both).isNone
doAssert render(both) == "a\n<<<<<<< ours\nX\n||||||| base\nb\n=======\nY\n>>>>>>> theirs\nc\n"
```

How the chunks are found. `lcs(base, ours)` and `lcs(base, theirs)` each give a set of base lines kept by that side. A base line kept by both is a sync point, and the three versions of the stretch between two sync points are compared: ours equal to theirs means both made the same change (or none); ours equal to the base means only theirs changed it; theirs equal to the base means only ours did; anything else is a conflict. Edits on neighbouring lines have no sync point between them, so they form one conflict hunk, as in `diff3`.

```nim
import nimcs/algo/three_way_merge

# line 2 edited by ours, line 3 by theirs: no stable line separates them
let adjacent = merge3(@["a", "b", "c"], @["a", "X", "c"], @["a", "b", "Y"])
doAssert adjacent == @[stable(@["a"]), conflict(@["b", "c"], @["X", "c"], @["b", "Y"])]
```

## Public API

Every exported symbol of `src/nimcs/algo/three_way_merge.nim`, generated by `nim apiSections` (the
tests fail when it drifts). `import nimcs/algo/three_way_merge` brings these names. A type they use from
another module (`Option`, `Result`, `Graph`) needs that module's import too, as in the example
above. A field marked `*` is readable outside the module; a type shown without fields is opaque,
built and read only through the functions.

```text
type KeyConflict[V] = object
  key*: string
  base*, ours*, theirs*: Option[V]
type KeyedMerge[V] = object
  case isClean*: bool
  of true:
    merged*: Table[string, V]
  of false:
    resolved*: Table[string, V]
    conflicts*: seq[KeyConflict[V]]
type Side = enum
  sOurs, sTheirs, sBoth
type ChunkKind = enum
  ckStable, ckClean, ckConflict
type Chunk[T] = object
  case kind*: ChunkKind
  of ckStable:
    stable*: seq[T]
  of ckClean:
    side*: Side
    taken*: seq[T]
  of ckConflict:
    base*, ours*, theirs*: seq[T]
func `==`[V](a, b: KeyedMerge[V]): bool
func swapSides[V](c: KeyConflict[V]): KeyConflict[V]
func swapSides[V](m: KeyedMerge[V]): KeyedMerge[V]
func mergeKeyed[V](base, ours, theirs: Table[string, V]): KeyedMerge[V]
func conflictKeys[V](m: KeyedMerge[V]): seq[string]
func stable[T](lines: seq[T]): Chunk[T]
func clean[T](side: Side; taken: seq[T]): Chunk[T]
func conflict[T](base, ours, theirs: seq[T]): Chunk[T]
func swapSides[T](chunks: seq[Chunk[T]]): seq[Chunk[T]]
func `==`[T](a, b: Chunk[T]): bool
func merge3[T](base, ours, theirs: openArray[T]): seq[Chunk[T]]
func conflictCount[T](chunks: seq[Chunk[T]]): int
func mergeLines[T](chunks: seq[Chunk[T]]): Option[seq[T]]
func toLines(text: string): seq[string]
func render(chunks: seq[Chunk[string]]; oursLabel = "ours"; baseLabel = "base"; theirsLabel = "theirs"): string
```

## Laws and invariants
Keyed merge (properties over small random maps):
- Unchanged, one-sided and identical changes are taken; changed differently on both sides is a conflict value, never an exception (STR-MERGE3-01, STR-MERGE3-02).
- The conflicting keys are exactly the keys changed differently on both sides (STR-MERGE3-03).
- merge(b, b, b) = b, merge(b, x, b) = x, merge(b, b, x) = x and merge(b, x, x) = x (STR-MERGE3-04).
- Swapping ours and theirs gives the same map, or the same conflicts with the sides exchanged (STR-MERGE3-05).
- A clean result carries every key either side changed, deletions included (STR-MERGE3-06).

Sequence merge (diff3):
- Hand-worked cases: separate edits combine, equal edits are clean, delete against modify, two insertions into one gap and neighbouring edits conflict (STR-MERGE3-07).
- merge3(b, b, b) is b, and merge3(b, x, b), merge3(b, b, x), merge3(b, x, x) read as x with no conflict (STR-MERGE3-08).
- Swapping ours and theirs gives the same chunks with the sides of every conflict exchanged (STR-MERGE3-09).
- When edits use unique lines and the merge is clean, it holds every line both sides kept and every inserted line, and none that either side deleted, each side's lines in their original order (STR-MERGE3-10).
- No two stable chunks touch, none is empty, and in a conflict ours, theirs and base are pairwise different (STR-MERGE3-11).
- `render` writes clean merges as their lines and fences conflicts with `<<<<<<<`, `|||||||`, `=======`, `>>>>>>>` (STR-MERGE3-12).

Only these are claimed. Diff3 does not satisfy every intuitive law (Khanna, Kunal and Pierce, "A Formal Investigation of Diff3"): for instance, edits on neighbouring lines conflict even though they touch different lines, and two different insertions into one gap always conflict, because the algorithm cannot say which should come first. Do not assume a merge of merges is independent of the order it is done in; the tests do not check it.

## Complexity
The keyed merge is O(n log n) in the total number of keys (collecting and sorting them; each lookup is O(1) on average). The sequence merge runs `lcs` twice, so time O(len base * (len ours + len theirs)) and space O(len base * max(len ours, len theirs)), plus a linear walk over the matches.

## Pitfalls
Merging two versions without the base cannot tell an addition from a deletion, and "newest wins" depends on clocks and throws one edit away:

```nim bad
for k, v in theirs:
  if k notin ours or v.mtime > ours[k].mtime:   # no base: a key missing from ours may be
    ours[k] = v                                  # its deletion, and an older edit is lost
```

Fix: decide every key from base, ours and theirs, and return the undecided ones as conflicts.

A merged record built field by field can leave a field out. A directory entry assembled for the merge result without its timestamp got 0, shown as 1970; the compiler accepted it because the field has a default. Build merged records through a constructor that needs every field, so a missing value is a compile error:

```nim bad
type Entry = object
  size: int64
  mtimeNs: int64

var merged = Entry()          # mtimeNs is 0 unless someone remembers to set it
merged.size = ours.size
```

Smaller traps: a clean merge is not a correct one (non-overlapping edits can still break each other); `toLines` makes a trailing newline end the last line, so a file with and without the final newline differs by that line and a merge may report it; `render` is for text and its conflict markers can themselves appear in the input.

## Related
`lcs.md` (the alignment under the sequence merge), `edit_distance.md` (the cost of the same two-sequence comparison, when a number rather than a script is wanted), and, in the design patterns, `event_sourcing.md` (a log of changes is the other way to converge two replicas) and `cqrs.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `e52e6b835f6d8607` Pro Git (section 3.2 Basic Branching and Merging: "Git does a simple three-way merge, using the two snapshots pointed to by the branch tips and the common ancestor of the two", and its Basic Merge Conflicts)

Read 2026-11-21 (catalog/concepts.json, round 4-lead). It covers the keyed merge of snapshots and conflicts, not the diff3 alignment; no catalog source was found for diff3 itself (searched by title for diff, merge, version control, git and patience). The laws of diff3 that do not hold are those reported by Khanna, Kunal and Pierce, "A Formal Investigation of Diff3", which is not in the catalog.
