import std/[unittest, options]
import propcheck
import nimcs/patterns/parallel_change

func name(given, family: string): Name {.raises: [].} =
  let n = initName(given, family)
  doAssert n.isOk
  n.value

func legacyOnly(n: Name): Record {.raises: [].} =
  ## A row written before the change: only the legacy text.
  Record(legacy: some(n.family & ", " & n.given), current: none(Name))

func word(): Gen[string] {.raises: [ValueError].} = stringOf("abcxyz", 1, 4)

# SPEC: PAT-PARALLELCHANGE-01
test "PAT-PARALLELCHANGE-01 Given a record written through either door, when read through both, then the legacy answer is the legacy text of the current answer":
  let outcome = check(pair(boolean(), pair(word(), word())),
      proc(x: (bool, (string, string))): bool {.raises: [CatchableError].} =
    let (viaCurrent, (given, family)) = x
    let n = name(given, family)
    let r = if viaCurrent: writeCurrent(n) else: writeLegacy(family & ", " & given).value
    r.readCurrent == some(n) and r.readLegacy == some(family & ", " & given))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-PARALLELCHANGE-02
test "PAT-PARALLELCHANGE-02 Given a row with only the legacy text, when read, then both readers answer, and an unparsable text reads as no current name":
  let outcome = check(pair(word(), word()), proc(x: (string, string)): bool {.raises: [CatchableError].} =
    let n = name(x[0], x[1])
    let r = legacyOnly(n)
    r.readLegacy == some(x[1] & ", " & x[0]) and r.readCurrent == some(n))
  checkpoint describe(outcome)
  check outcome.passed
  let bad = check(stringOf("ab, ", 0, 6), proc(s: string): bool {.raises: [CatchableError].} =
    var hasSeparator = false
    for i in 0 ..< s.len - 1:
      if s[i] == ',' and s[i + 1] == ' ': hasSeparator = true
    hasSeparator or Record(legacy: some(s), current: none(Name)).readCurrent.isNone)
  checkpoint describe(bad)
  check bad.passed

# SPEC: PAT-PARALLELCHANGE-03
test "PAT-PARALLELCHANGE-03 Given any rows, when backfilled, then it is idempotent, no reader's answer changes and every parsable row has a current name":
  let outcome = check(seqOf(pair(intIn(0, 2), pair(word(), word())), 0, 6),
      proc(xs: seq[(int, (string, string))]): bool {.raises: [CatchableError].} =
    var rows: Store = @[]
    for x in xs:
      let (kind, (a, b)) = x
      let n = name(a, b)
      case kind
      of 0: rows.add writeCurrent(n)
      of 1: rows.add legacyOnly(n)
      else: rows.add Record(legacy: some(a & "|" & b), current: none(Name))   # does not parse
    for r in rows:
      let b = r.backfill
      if b.backfill != b or b.readLegacy != r.readLegacy or b.readCurrent != r.readCurrent: return false
      if r.readCurrent.isSome and b.current.isNone: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-PARALLELCHANGE-04
test "PAT-PARALLELCHANGE-04 Given a store, when contracted, then it is refused at the first row without a current name, and succeeds after backfill with every current answer kept":
  let outcome = check(seqOf(pair(boolean(), pair(word(), word())), 0, 6),
      proc(xs: seq[(bool, (string, string))]): bool {.raises: [CatchableError].} =
    var rows: Store = @[]
    var firstOld = -1
    for i, x in xs:
      let (migrated, (a, b)) = x
      let n = name(a, b)
      if migrated: rows.add writeCurrent(n)
      else:
        rows.add legacyOnly(n)
        if firstOld < 0: firstOld = i
    let first = contract(rows)
    if firstOld >= 0:
      if first.isOk or first.error.firstUnmigrated != firstOld: return false
    elif first.isErr:
      return false
    var filled: Store = @[]
    for r in rows: filled.add r.backfill
    let after = contract(filled)
    if after.isErr: return false
    for i in 0 ..< rows.len:
      if after.value[i].readCurrent != rows[i].readCurrent or after.value[i].legacy.isSome: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed
  check contract(@[]).isOk   # nothing to lose

# SPEC: PAT-PARALLELCHANGE-05
test "PAT-PARALLELCHANGE-05 Given parts that may be empty or hold commas, when a name is built, then bad parts are refused and a good name survives the legacy text":
  check initName("", "a").error == neEmptyGiven
  check initName("a", "").error == neEmptyFamily
  check initName("a,b", "c").error == neComma
  check initName("a", "c,").error == neComma
  check parseLegacy("no separator").error == neNoSeparator
  check writeLegacy("Doe,John").isErr
  let outcome = check(pair(stringOf("ab, ", 0, 5), stringOf("ab, ", 0, 5)),
      proc(x: (string, string)): bool {.raises: [CatchableError].} =
    let n = initName(x[0], x[1])
    (not n.isOk) or parseLegacy(formatLegacy(n.value)) == n)
  checkpoint describe(outcome)
  check outcome.passed
