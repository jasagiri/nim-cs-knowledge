## Typestate: the state of a value is part of its type, so an operation that is wrong in a state
## does not compile.
##
## A blob of bytes is first a draft (`Blob[Draft]`: you may write to it) and then published
## (`Blob[Published]`: read-only, with a content id). `Draft` and `Published` are empty types that
## exist only to be a parameter of `Blob`; they add nothing at run time. `write` takes a
## `Blob[Draft]`, so `write(published, ...)` is a compile error, and `contentId` takes a
## `Blob[Published]`, so a draft has no id to quote. `publish` takes the draft and returns the
## published value; the published value holds its own copy of the bytes, so writing to a stale
## draft afterwards cannot change what was published (Nim values are copied, there is no shared
## path or handle behind them).
##
## The state of a value is sometimes known only at run time (a record read from disk). That case is
## the second half of the module: `Stored` is the unchecked record (an object variant on its
## state), `asDraft` and `asPublished` are the only ways from it to a typed blob and each returns a
## `Result`, and `writeStored` and `publishStored` act on it directly and answer a wrong state with
## a `Result` instead of refusing to compile.
##
## Honest limit: Nim has no affine types. `publish(d)` does not stop the caller from using `d`
## again, and a `{.error.}` on `=copy` that would stop it cannot ride through the repository's
## `Result` (see `details/typestate.md`), so `Blob` stays copyable. What the types do guarantee is
## that no routine accepts a blob in a state it is wrong for.
##
## `contentId` is a 64-bit FNV-1a digest in hexadecimal: deterministic and cheap, not a
## cryptographic hash. A system that must resist forged collisions replaces `digest` with a
## cryptographic one; the typestate does not change.

import std/strutils
import nimcs/fp/result

export result

type
  Draft* = object
    ## State tag: the blob may be written.
  Published* = object
    ## State tag: the blob is read-only and has a content id.

  Blob*[S] {.requiresInit.} = object
    ## Bytes in state `S` (`Draft` or `Published`). The field is private: the only ways to get a
    ## `Blob[Published]` are `publish` and `asPublished`.
    bytes: string

  ContentId* = distinct string
    ## Hexadecimal digest of the content of a published blob.

  RecordState* = enum
    ## The state tag of a stored record, as read from outside the program.
    rsDraft, rsPublished

  Stored* = object
    ## An unchecked record in a state known only at run time, for example read from disk. Nothing
    ## here is trusted: anyone can build one in any state.
    bytes*: string
    case state*: RecordState
    of rsDraft:
      discard
    of rsPublished:
      id*: string        ## the recorded content id

  StateError* = enum
    seNotDraft, seNotPublished, seIdMismatch

func `==`*(a, b: ContentId): bool {.raises: [].} = string(a) == string(b)
func `$`*(c: ContentId): string {.raises: [].} = string(c)

func `==`*[S](a, b: Blob[S]): bool {.raises: [].} = a.bytes == b.bytes

func digest(bytes: string): ContentId {.raises: [].} =
  const
    offset = 0xcbf29ce484222325'u64
    prime = 0x100000001b3'u64
  var h = offset
  for c in bytes:
    h = (h xor uint64(ord(c))) * prime
  ContentId(toHex(h))

func newDraft*(): Blob[Draft] {.raises: [].} =
  ## An empty draft.
  Blob[Draft](bytes: "")

func write*(b: Blob[Draft]; data: string): Blob[Draft] {.raises: [].} =
  ## The draft with `data` appended. Only a draft can be written.
  Blob[Draft](bytes: b.bytes & data)

func publish*(b: Blob[Draft]): Blob[Published] {.raises: [].} =
  ## The read-only blob with the draft's content. The result owns its bytes.
  Blob[Published](bytes: b.bytes)

func read*[S](b: Blob[S]): string {.raises: [].} =
  ## The content, in either state.
  b.bytes

func size*[S](b: Blob[S]): int {.raises: [].} =
  ## The number of bytes, in either state.
  b.bytes.len

func contentId*(b: Blob[Published]): ContentId {.raises: [].} =
  ## The id of the content. Equal content has an equal id however it was written.
  digest(b.bytes)

func store*(b: Blob[Draft]): Stored {.raises: [].} =
  ## The record of a draft, as written to disk.
  Stored(state: rsDraft, bytes: b.bytes)

func store*(b: Blob[Published]): Stored {.raises: [].} =
  ## The record of a published blob, with its content id.
  Stored(state: rsPublished, bytes: b.bytes, id: $contentId(b))

func asDraft*(r: Stored): Result[Blob[Draft], StateError] {.raises: [].} =
  ## Accepts exactly a record in state `rsDraft`.
  if r.state != rsDraft: return err(Blob[Draft], seNotDraft)
  ok(Blob[Draft](bytes: r.bytes), StateError)

func asPublished*(r: Stored): Result[Blob[Published], StateError] {.raises: [].} =
  ## Accepts exactly a record in state `rsPublished` whose recorded id is the digest of its bytes.
  if r.state != rsPublished: return err(Blob[Published], seNotPublished)
  if r.id != $digest(r.bytes): return err(Blob[Published], seIdMismatch)
  ok(Blob[Published](bytes: r.bytes), StateError)

func `==`*(a, b: Stored): bool {.raises: [].} =
  if a.state != b.state or a.bytes != b.bytes: return false
  case a.state
  of rsDraft: true
  of rsPublished: a.id == b.id

func writeStored*(r: Stored; data: string): Result[Stored, StateError] {.raises: [].} =
  ## `write` for a record of unknown state; a published record is `seNotDraft`.
  case r.state
  of rsDraft: ok(Stored(state: rsDraft, bytes: r.bytes & data), StateError)
  of rsPublished: err(Stored, seNotDraft)

func publishStored*(r: Stored): Result[Stored, StateError] {.raises: [].} =
  ## `publish` for a record of unknown state; a record already published is `seNotDraft`.
  case r.state
  of rsDraft: ok(store(Blob[Published](bytes: r.bytes)), StateError)
  of rsPublished: err(Stored, seNotDraft)
