# Typestate

## Intent
Some values are legal for different operations at different times: a draft may be written, a published blob may only be read. Keep the state in the type (`Blob[Draft]`, `Blob[Published]`), give each operation the state it is right for, and let a transition (`publish`) take one state and return the other. Then an operation that is wrong in a state does not compile, instead of being a check that somebody has to remember to run.

The defect this prevents: a file server let a client write a temporary file and then rename it into a content-addressed area, after which it had to be read-only. The policy kept treating the open handle by its old temporary path, so the client could still overwrite content that had been verified. The state ("still a draft" or "published") lived in a path string next to the handle, and nothing connected the two. With typestate, "a draft you may write" and "a published, read-only blob" are different types, `publish` consumes the draft and returns the published value, and `write` on a published value does not compile.

## Use when / avoid when
- Use when an operation is legal only in some states and the state changes through your own code (open and closed, draft and published, unverified and verified, connected and disconnected).
- Use when a wrong-state call is expensive: it corrupts verified data, leaks a resource, or sends a message that cannot be taken back.
- Use at the boundary where the state becomes known at run time (a record read from disk): one checked constructor per state turns the unchecked record into the typed value, so everything after it is checked by the compiler.
- Avoid it when the state is only ever known at run time and changes in a loop driven by input (a protocol reading arbitrary messages): use an object variant and `Result` (`state_machine.md`), the compiler cannot follow a state chosen by data.
- Avoid it for a value with one legal state and a rule on its content: that is a smart constructor (`smart_constructor.md`), not a typestate.
- Avoid a type per state when two states differ only in one flag nobody branches on; a field is enough.

## Nim shape
There are three ways in Nim; the module uses the second and offers the third for the run-time case.

1. Distinct types per state: `DraftBlob` and `PublishedBlob` are separate `distinct` or object types, each with its own routines. It is the plainest and needs no generics. The cost is that every shared routine (`read`, `size`) is written twice or goes through a `converter`, and a `converter` erases the state (see Pitfalls).
2. A phantom generic parameter: `Blob[S]` with empty state types `Draft` and `Published`. A routine for one state names it (`write(b: Blob[Draft]; ...)`), a routine for any state is generic (`read[S](b: Blob[S])`), and the code is written once. A `static` enum parameter (`Blob[st: static BlobState]`) works the same way and keeps the states in one enum, at the price of a constraint written as `Blob[bsDraft]` in every signature and an enum you must extend for each state.
3. At run time, an object variant on the state with a `Result` from each operation (`Stored`, `writeStored`, `publishStored`). It cannot refuse to compile, because the state is data, so a wrong-state call is an error value.

The module is `src/nimcs/fp/typestate.nim`. It chooses the phantom parameter because the two states share most of their code and the tag costs nothing at run time (Complexity), and because it reads like the rule: `write` takes a draft. The field of `Blob` is private and the type is `{.requiresInit.}`, so the only ways to get a `Blob[Published]` are `publish` and the checked bridge `asPublished`.

```nim
import nimcs/fp/typestate

let draft = newDraft().write("hello, ").write("world")
let blob = draft.publish
doAssert blob.read == "hello, world"
doAssert draft.write("!").read == "hello, world!"   # a draft is still writable
doAssert blob.read == "hello, world"                # and the published blob did not change
doAssert $blob.contentId == $newDraft().write("hello, world").publish.contentId
```

The compiler refuses the wrong state:

```nim
import nimcs/fp/typestate

let published = newDraft().write("verified").publish
doAssert not compiles(published.write("overwritten"))   # no write on a published blob
doAssert not compiles(published.publish)                # published once is published
doAssert not compiles(newDraft().contentId)             # a draft has no content id yet
doAssert not compiles(Blob[Published](bytes: "forged")) # the field is private
doAssert not compiles(block:
  var unset: Blob[Published]                            # {.requiresInit.}: no default value
  unset)
```

The state is often known only after reading a record. The bridge from run time to typestate is a checked constructor returning `Result`, one per state; each accepts exactly the records that are in that state, and `asPublished` also checks that the recorded id is the digest of the bytes:

```nim
import nimcs/fp/typestate

let onDisk = newDraft().write("data").publish.store          # what was written
doAssert onDisk.asPublished.isOk
doAssert onDisk.asDraft.error == seNotDraft                   # not writable: it is published
doAssert Stored(state: rsPublished, bytes: "data", id: "0000000000000000").asPublished.error == seIdMismatch
let again = onDisk.asPublished
if again.isOk:                      # `.value` is only read once isOk is known
  doAssert again.value.read == "data"
```

When the state really is data, act on the record and get a `Result` (the runtime alternative, third way):

```nim
import nimcs/fp/typestate

let rec = newDraft().write("a").store
let written = rec.writeStored("b")
doAssert written.isOk and written.value.bytes == "ab"
let sealed = written.value.publishStored
doAssert sealed.isOk
doAssert sealed.value.writeStored("c").error == seNotDraft   # a value, not a compile error
```

### Can `sink` or a disabled `=copy` stop reuse of the draft?
Nim has no affine (use-once) types, so `publish(d)` does not stop the caller from using `d` afterwards, and the module's `Blob` is copyable: `let q = d.publish` after `let p = d.publish` compiles (checked by FP-TYPESTATE-07). What can be done is a move-only handle: declare `=copy` with `{.error.}` for the type and take the draft as `sink` in `publish`. Then using the draft after it was moved in is a compile error, with the strict `nim.cfg` too (Nim 2.4.2, `--mm:orc`; the same file under `nim c` fails, FP-TYPESTATE-07 compiles it):

```nim
type
  Draft = object
  Published = object
  Handle[S] {.requiresInit.} = object
    data: string

proc `=copy`[S](dst: var Handle[S]; src: Handle[S]) {.error.}

func publish(h: sink Handle[Draft]): Handle[Published] {.raises: [].} =
  Handle[Published](data: h.data)

proc run(): string =
  let d = Handle[Draft](data: "x")
  let p = publish(d)        # the last use of d: it is moved
  # let q = publish(d)      # error: '=dup' is not available ... not the last read of 'd'
  p.data

doAssert run() == "x"
```

Four limits, each found by compiling:
- The error comes from the move analysis after type checking. `nim check` and `compiles(...)` do not see it (a call that uses the moved value twice still passes `compiles`); only `nim c` (also `--compileOnly`) reports it, so a test needs a real compile, as FP-TYPESTATE-07 does.
- A module-level `let` is never moved, so the same code at the top level of a file fails even for a single use ("not the last read"); put the use in a `proc`.
- Any read of the old value after the move is refused, not only a second `publish`: `echo d.data` after `publish(d)` fails too.
- The repository's `Result` cannot hold such a type: `ok(v, E)` copies its argument, so `Result[Handle[Draft], E]` does not compile ("try to make v a 'sink' parameter"). The module therefore keeps `Blob` copyable and states this limit rather than hiding it. A bridge for a move-only handle needs its own result type whose constructor takes `sink`.

The copyable `Blob` is still safe against the defect above, for a different reason: `Blob[Published]` owns a copy of the bytes, so a stale `Blob[Draft]` cannot reach it (nothing is shared through a path or a handle), and no routine takes a published blob to write.

## Public API

Every exported symbol of `src/nimcs/fp/typestate.nim`, generated by `nim apiSections` (the
tests fail when it drifts). `import nimcs/fp/typestate` brings these names. A type they use from
another module (`Option`, `Result`, `Graph`) needs that module's import too, as in the example
above. A field marked `*` is readable outside the module; a type shown without fields is opaque,
built and read only through the functions.

```text
type Draft = object
type Published = object
type Blob[S] {.requiresInit.} = object
type ContentId = distinct string
type RecordState = enum
  rsDraft, rsPublished
type Stored = object
  bytes*: string
  case state*: RecordState
  of rsDraft:
    nil
  of rsPublished:
    id*: string              ## the recorded content id
type StateError = enum
  seNotDraft, seNotPublished, seIdMismatch
func `==`(a, b: ContentId): bool
func `$`(c: ContentId): string
func `==`[S](a, b: Blob[S]): bool
func newDraft(): Blob[Draft]
func write(b: Blob[Draft]; data: string): Blob[Draft]
func publish(b: Blob[Draft]): Blob[Published]
func read[S](b: Blob[S]): string
func size[S](b: Blob[S]): int
func contentId(b: Blob[Published]): ContentId
func store(b: Blob[Draft]): Stored
func store(b: Blob[Published]): Stored
func asDraft(r: Stored): Result[Blob[Draft], StateError]
func asPublished(r: Stored): Result[Blob[Published], StateError]
func `==`(a, b: Stored): bool
func writeStored(r: Stored; data: string): Result[Stored, StateError]
func publishStored(r: Stored): Result[Stored, StateError]
```

## Laws and invariants
Why this is testable: every operation is a `func`, and the forbidden ones are `compiles` checks, so a law can be stated for any content and the refusals are asserted without running anything.
- What is written to a draft, in any pieces, is what the published blob reads (FP-TYPESTATE-01).
- An operation of the other state does not compile; a published blob cannot be forged or left unset (FP-TYPESTATE-02).
- Publishing is deterministic and content-addressed, and a later write to a stale draft does not change the published blob (FP-TYPESTATE-03).
- The run-time bridge accepts exactly the valid records and names the reason for the others (FP-TYPESTATE-04), and `store` then the bridge is the identity for the same state and a refusal for the other (FP-TYPESTATE-05).
- The run-time operations agree with the typed ones and answer a wrong state with a value (FP-TYPESTATE-06).
- A move-only handle makes reuse of the draft a compile error, the repository's `Result` cannot carry it, and the copyable `Blob` allows the reuse (FP-TYPESTATE-07).
- The state tags add nothing to the size of the value (FP-TYPESTATE-08).

## Complexity
Zero run-time cost for the states: `Draft` and `Published` are never constructed, and `Blob[Draft]` and `Blob[Published]` are each exactly one `string`, as large as a `string` (FP-TYPESTATE-08); the checks happen at compile time. The operations cost what the data costs: `write` and `publish` copy the bytes (O(n)), `contentId` reads them once (O(n)). The bridge costs one comparison for a draft and one digest for a published record. A `static` enum parameter has the same zero cost; a variant with `Result` pays a tag and a branch per call.

## Pitfalls
Keeping a path or string identity next to the typed handle, as in the defect: the handle is typed, but the decision is taken on the string, so the type protects nothing.

```nim bad
type
  Handle = object
    path: string          # the state is encoded in the path: "/tmp/x" is a draft, "/blobs/ab12" is published
    fd: int

proc mayWrite(h: Handle): bool =
  h.path.startsWith("/tmp/")      # the handle was renamed into /blobs, but this path is the old one

proc rename(h: var Handle; to: string) =
  discard                          # moves the file, forgets to update h.path: the client can still write
```

Fix: make the state a type parameter (`Blob[Draft]`, `Blob[Published]`) and let the transition return the new value; there is no string to go stale.

Two more ways to lose the guarantee:
- A `converter` from `Blob[Published]` to `Blob[Draft]` (or from either to a stateless base type) erases the state silently, and `write(published, ...)` compiles again. Never write a `converter` between states.
- Exporting the raw constructor (`bytes*` public, or no `{.requiresInit.}`) lets any module build a `Blob[Published]` without going through `publish` or `asPublished`; keep the field private and build only in the module that owns the transitions.

A generic routine `proc write[S](b: Blob[S]; ...)` is also a hole: `S` is then unconstrained and a published blob is accepted. Name the state in the signature.

## Related
- `smart_constructor.md` (the checked constructor that is the bridge from run time to the typed value)
- `adt.md` (the object variant used for the run-time form)
- `src/nimcs/fp/result.nim` and `result.md` (what the bridge returns)
- `state.md` and `state_machine.md` in nim-design-patterns (the run-time forms of states and transitions; this page moves the legal ones into the type)
- `object_capability.md` and `sealer_unsealer.md` in nim-design-patterns (other ways to make a forbidden operation unwritable)
- `atomic_publish.md` in nim-design-patterns (the protocol whose published file must stop being writable, the defect this page starts from)

## Sources

None in the catalog: no source in catalog/sources.jsonl was found whose title covers typestate, phantom types, session types or type-driven design (searched 2026-11-21 by title for typestate, phantom, session type, type-driven, affine, linear type, illegal state and Rust; the Rust and dependent-types titles found are general books, none read as covering typestate, and the page cites no source it has not read).
