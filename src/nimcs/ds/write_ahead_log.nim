## Write-ahead log as a value: an append-only sequence of records, each with a sequence number and a
## checksum, that can be replayed to rebuild state and survive a torn tail.
##
## `append` returns a new log holding one more record (the old log is unchanged). `replay` folds a
## function over the payloads in order, so the state a program had is the state it rebuilds from the
## log; because the fold is pure, replaying twice gives the same state. `encode` turns the log into
## one byte string (per record: sequence number, payload length, payload, CRC-32 over those three,
## all integers big-endian) and `recover` reads such a string back. A crash can leave the last record
## short or half written: `recover` keeps every record up to the first one that is short, fails its
## checksum or carries the wrong sequence number, and drops that record and whatever follows,
## reporting how many bytes it dropped. A log is trusted only as far as its checksums, so it stops at
## the first bad record and never skips over it to a later good one.
##
## Out of scope: files. Writing the bytes, `fsync`, truncating a file to `keptBytes`, rotating and
## checkpointing segments are effects, and belong in the imperative shell around this value (use
## `encode` to get the bytes to write and `recover` on the bytes read). The checksum is CRC-32: it
## finds accidental damage, not tampering.

import std/options
import nimcs/fp/result
export result

const
  maxPayload* = 1 shl 24
    ## The largest payload `append` accepts, in bytes. A length field read from damaged bytes is
    ## compared with this before anything is allocated.
  headerLen = 12            # 8 bytes of sequence number, 4 bytes of payload length
  checksumLen = 4

type
  WalError* = enum
    weTooLarge,             ## a payload longer than `maxPayload`
    weCorrupt               ## `decodeStrict` found bytes that are not a whole, intact log
  WalEntry* = object
    seqNo*: int
    payload*: string
    checksum*: uint32       ## CRC-32 of the sequence number, length and payload as encoded
  Wal* = object
    items: seq[WalEntry]
  Recovery* = object
    log*: Wal               ## the records that were read intact, a prefix of what was written
    keptBytes*: int         ## length of the prefix of the input that holds exactly those records
    droppedBytes*: int      ## bytes after that prefix: a torn or damaged tail

func emptyLog*(): Wal {.raises: [].} =
  Wal(items: @[])

func len*(log: Wal): int {.raises: [].} =
  ## Number of records.
  log.items.len

func nextSeq*(log: Wal): int {.raises: [].} =
  ## The sequence number the next appended record gets: 0 for an empty log, then 1, 2, ...
  log.items.len

func entries*(log: Wal): seq[WalEntry] {.raises: [].} =
  log.items

func payloads*(log: Wal): seq[string] {.raises: [].} =
  for e in log.items:
    result.add e.payload

func at*(log: Wal; seqNo: int): Option[WalEntry] {.raises: [].} =
  ## The record with that sequence number; none when there is none.
  if seqNo < 0 or seqNo >= log.items.len: none(WalEntry)
  else: some(log.items[seqNo])

func `==`*(a, b: Wal): bool {.raises: [].} =
  a.items == b.items

# --- checksum and byte layout ---------------------------------------------------------------------

func crc32*(data: string): uint32 {.raises: [].} =
  ## CRC-32 (the IEEE 802.3 polynomial, reflected, as in zlib and gzip); `crc32("123456789")` is
  ## 0xCBF43926.
  var c = 0xffffffff'u32
  for ch in data:
    c = c xor uint32(ord(ch))
    for _ in 0 ..< 8:
      c = if (c and 1'u32) != 0'u32: (c shr 1) xor 0xedb88320'u32 else: c shr 1
  c xor 0xffffffff'u32

func bigEndian(v: uint64; width: int): string =
  for i in countdown(width - 1, 0):
    result.add char((v shr (i * 8)) and 0xff'u64)

func readBigEndian(s: string; at, width: int): uint64 =
  for i in 0 ..< width:
    result = (result shl 8) or uint64(ord(s[at + i]))

func recordBody(seqNo: int; payload: string): string =
  bigEndian(uint64(seqNo), 8) & bigEndian(uint64(payload.len), 4) & payload

# --- building and reading -------------------------------------------------------------------------

func append*(log: Wal; payload: string): Result[Wal, WalError] {.raises: [].} =
  ## The log with `payload` as a new last record. O(n) in the number of records, because the new
  ## value holds its own sequence (this is a value type, not a file); `appendAll` does a batch in one copy.
  if payload.len > maxPayload: return err(Wal, weTooLarge)
  let n = log.items.len
  let entry = WalEntry(seqNo: n, payload: payload, checksum: crc32(recordBody(n, payload)))
  ok(Wal(items: log.items & @[entry]), WalError)

func appendAll*(log: Wal; payloadList: openArray[string]): Result[Wal, WalError] {.raises: [].} =
  ## Appends the payloads in order, all or none.
  var items = log.items
  for p in payloadList:
    if p.len > maxPayload: return err(Wal, weTooLarge)
    let n = items.len
    items.add WalEntry(seqNo: n, payload: p, checksum: crc32(recordBody(n, p)))
  ok(Wal(items: items), WalError)

func replay*[S](log: Wal; initial: S;
    apply: proc(state: S; payload: string): S {.noSideEffect, raises: [].}): S {.raises: [].} =
  ## The state after applying every payload, oldest first, to `initial`. Pure: replaying the same
  ## log with the same function from the same state always gives the same state.
  result = initial
  for e in log.items:
    result = apply(result, e.payload)

func encode*(log: Wal): string {.raises: [].} =
  ## The log as bytes: record after record, each `seq (8) length (4) payload checksum (4)`.
  for e in log.items:
    result.add recordBody(e.seqNo, e.payload)
    result.add bigEndian(uint64(e.checksum), checksumLen)

func recover*(bytes: string): Recovery {.raises: [].} =
  ## Reads as many whole, intact records as the bytes start with. Never fails and never reads past
  ## the end: a record that is short, whose length field is larger than the bytes left or than
  ## `maxPayload`, whose sequence number is not the next one, or whose checksum does not match,
  ## ends the log there. For every input, `encode(recover(bytes).log)` is the first `keptBytes`
  ## bytes of `bytes`.
  var items: seq[WalEntry]
  var at = 0
  while bytes.len - at >= headerLen + checksumLen:
    let sq = readBigEndian(bytes, at, 8)
    let n = readBigEndian(bytes, at + 8, 4)
    if sq != uint64(items.len): break
    if n > uint64(maxPayload) or n > uint64(bytes.len - at - headerLen - checksumLen): break
    let bodyEnd = at + headerLen + int(n)
    let stored = uint32(readBigEndian(bytes, bodyEnd, checksumLen))
    let body = bytes[at ..< bodyEnd]
    if crc32(body) != stored: break
    items.add WalEntry(seqNo: items.len, payload: bytes[at + headerLen ..< bodyEnd], checksum: stored)
    at = bodyEnd + checksumLen
  Recovery(log: Wal(items: items), keptBytes: at, droppedBytes: bytes.len - at)

func decodeStrict*(bytes: string): Result[Wal, WalError] {.raises: [].} =
  ## The log in `bytes` when every byte belongs to an intact record; `weCorrupt` otherwise. Use it
  ## for a log that was closed cleanly (a snapshot, a shipped segment); use `recover` after a crash.
  let r = recover(bytes)
  if r.droppedBytes == 0: ok(r.log, WalError)
  else: err(Wal, weCorrupt)
