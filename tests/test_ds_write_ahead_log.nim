import std/[unittest, options]
import propcheck
import nimcs/ds/write_ahead_log

func logOf(ps: openArray[string]): Wal =
  let r = emptyLog().appendAll(ps)
  doAssert r.isOk
  r.value

func recordLen(payload: string): int =
  16 + payload.len        # 8 seq + 4 length + payload + 4 checksum

func fold(state: string; payload: string): string {.raises: [].} =
  state & "<" & payload & ">"

func countBytes(state: int; payload: string): int {.raises: [].} =
  state + payload.len

func startOf(ps: seq[string]; k: int): int =
  ## Byte offset where record k starts in the encoding.
  for i in 0 ..< k:
    result += recordLen(ps[i])

suite "write_ahead_log":
  # SPEC: DS-WRITEAHEADLOG-01
  test "DS-WRITEAHEADLOG-01 Given a log, when appending payloads, then they get sequence numbers 0, 1, 2 in order and the old log is unchanged":
    let outcome = check(seqOf(stringOf("ab\0", 0, 6), 0, 20),
      proc(ps: seq[string]): bool {.raises: [CatchableError].} =
        var log = emptyLog()
        for p in ps:
          let before = log
          let r = log.append(p)
          if not r.isOk or before.len != log.len: return false
          log = r.value
          if log.len != before.len + 1 or log.nextSeq != log.len: return false
        if log.payloads != ps: return false
        for i, e in log.entries:
          if e.seqNo != i or log.at(i) != some(e): return false
        log.at(-1).isNone and log.at(ps.len).isNone)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-WRITEAHEADLOG-02
  test "DS-WRITEAHEADLOG-02 Given a log, when replaying, then the state is the left fold of apply over the payloads and the empty log gives the initial state":
    let outcome = check(seqOf(stringOf("xyz", 0, 5), 0, 20),
      proc(ps: seq[string]): bool {.raises: [CatchableError].} =
        let log = logOf(ps)
        var expected = "start"
        var total = 0
        for p in ps:
          expected = fold(expected, p)
          total += p.len
        if log.replay("start", fold) != expected: return false
        if log.replay(0, countBytes) != total: return false
        emptyLog().replay("start", fold) == "start")
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-WRITEAHEADLOG-03
  test "DS-WRITEAHEADLOG-03 Given any log, when encoded and recovered, then the same log comes back with nothing dropped":
    let outcome = check(seqOf(stringOf("ab\0\xff", 0, 8), 0, 20),
      proc(ps: seq[string]): bool {.raises: [CatchableError].} =
        let log = logOf(ps)
        let bytes = log.encode
        let r = recover(bytes)
        if r.log != log or r.keptBytes != bytes.len or r.droppedBytes != 0: return false
        let s = decodeStrict(bytes)
        s.isOk and s.value == log)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-WRITEAHEADLOG-04
  test "DS-WRITEAHEADLOG-04 Given an encoded log cut at any byte, when recovering, then exactly the records wholly before the cut are kept and the rest is dropped":
    let outcome = check(seqOf(stringOf("ab\0", 0, 6), 0, 8),
      proc(ps: seq[string]): bool {.raises: [CatchableError].} =
        let bytes = logOf(ps).encode
        for cut in 0 .. bytes.len:
          var whole = 0
          while whole < ps.len and startOf(ps, whole + 1) <= cut: inc whole
          let r = recover(bytes[0 ..< cut])
          if r.log != logOf(ps[0 ..< whole]): return false
          if r.keptBytes != startOf(ps, whole) or r.droppedBytes != cut - r.keptBytes: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-WRITEAHEADLOG-05
  test "DS-WRITEAHEADLOG-05 Given an encoded log, when any one byte is changed, then recovery keeps exactly the records before the damaged one":
    let outcome = check(seqOf(stringOf("ab\0", 0, 6), 1, 8),
      proc(ps: seq[string]): bool {.raises: [CatchableError].} =
        let bytes = logOf(ps).encode
        for pos in 0 ..< bytes.len:
          var k = 0                     # the record that holds byte `pos`
          while startOf(ps, k + 1) <= pos: inc k
          var damaged = bytes
          damaged[pos] = char(ord(damaged[pos]) xor 0x01)
          let r = recover(damaged)
          if r.log != logOf(ps[0 ..< k]): return false
          if r.keptBytes != startOf(ps, k) or r.droppedBytes != bytes.len - r.keptBytes: return false
          if decodeStrict(damaged) != err(Wal, weCorrupt): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-WRITEAHEADLOG-06
  test "DS-WRITEAHEADLOG-06 Given arbitrary bytes, when recovering, then it never fails and the recovered log encodes to the kept prefix":
    let outcome = check(stringOf("\0\1\2ab\xff", 0, 80),
      proc(junk: string): bool {.raises: [CatchableError].} =
        let r = recover(junk)
        if r.keptBytes + r.droppedBytes != junk.len: return false
        if r.log.encode != junk[0 ..< r.keptBytes]: return false
        # junk after a valid log never removes the records before it
        let log = logOf(["first", "second"])
        let both = recover(log.encode & junk)
        both.log.len >= 2 and both.log.entries[0 ..< 2] == log.entries)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-WRITEAHEADLOG-07
  test "DS-WRITEAHEADLOG-07 Given a log with a torn tail, when recovering twice and replaying twice, then every step gives the same log and the same state":
    let outcome = check(pair(seqOf(stringOf("ab", 0, 5), 1, 10), intIn(1, 15)),
      proc(a: (seq[string], int)): bool {.raises: [CatchableError].} =
        let bytes = logOf(a[0]).encode
        let torn = bytes[0 ..< max(0, bytes.len - a[1])]
        let first = recover(torn)
        let second = recover(first.log.encode)
        if second.log != first.log or second.droppedBytes != 0: return false
        first.log.replay("", fold) == second.log.replay("", fold))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-WRITEAHEADLOG-08
  test "DS-WRITEAHEADLOG-08 Given known inputs, when computing crc32, then the standard check values come out":
    check crc32("") == 0'u32
    check crc32("123456789") == 0xCBF43926'u32
    check crc32("a") == 0xE8B7BE43'u32

  # SPEC: DS-WRITEAHEADLOG-09
  test "DS-WRITEAHEADLOG-09 Given a payload over the limit or a length field larger than the bytes left, then append refuses it and recover stops without reading past the end":
    let big = newString(maxPayload + 1)
    check emptyLog().append(big) == err(Wal, weTooLarge)
    check emptyLog().appendAll(["ok", big]) == err(Wal, weTooLarge)
    check emptyLog().append(newString(maxPayload)).isOk
    # record 0 with a length of 0xffffffff and no payload: the header alone, then twenty more bytes
    let lying = "\0\0\0\0\0\0\0\0\xff\xff\xff\xff" & newString(20)
    let r = recover(lying)
    check r.log.len == 0
    check r.keptBytes == 0
    check r.droppedBytes == lying.len
    check recover("").droppedBytes == 0

  # SPEC: DS-WRITEAHEADLOG-09
  test "DS-WRITEAHEADLOG-09 Given payloads of 16 MiB and one byte more, then append and appendAll accept the first and refuse the second, and recover reads the first back":
    check emptyLog().append(newString(16_777_216)).isOk
    check emptyLog().append(newString(16_777_217)) == err(Wal, weTooLarge)
    let batch = emptyLog().appendAll([newString(16_777_216)])
    check batch.isOk
    check emptyLog().appendAll([newString(16_777_217)]) == err(Wal, weTooLarge)
    let r = recover(batch.value.encode)
    check r.log.len == 1
    check r.droppedBytes == 0
    check r.log.at(0).get.payload.len == 16_777_216
