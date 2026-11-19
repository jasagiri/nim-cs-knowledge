import std/[unittest, algorithm]
import propcheck
import nimcs/fp/[result, idempotence]

func ledgerCommands(): Gen[seq[Command]] {.raises: [ValueError].} =
  # The amount is a function of the key, so that a replay is a true retry (no key conflicts).
  seqOf(pick(["k1", "k2", "k3", "k4", "k5"]), 0, 10).map(
    proc(keys: seq[string]): seq[Command] {.raises: [].} =
      for k in keys:
        result.add Command(key: k, amount: (ord(k[1]) - 48) * 7 - 10))

func sortedSets(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-10, 10), 0, 10).map(proc(xs: seq[int]): seq[int] {.raises: [].} =
    for x in xs.sorted:
      if result.len == 0 or result[^1] != x:
        result.add x)

func entries(): Gen[seq[Entry]] {.raises: [ValueError].} =
  # Built directly, so duplicate keys are possible.
  seqOf(pair(pick(["a", "b", "c", "d"]), intIn(-9, 9)), 0, 8).map(
    proc(ps: seq[(string, int)]): seq[Entry] {.raises: [].} =
      for p in ps:
        result.add Entry(key: p[0], value: p[1]))

# SPEC: FP-IDEMPOTENCE-01
test "FP-IDEMPOTENCE-01 Given any text, when normalizeSpaces is applied twice, then it equals applying once":
  check normalizeSpaces("  a   b  ") == "a b"
  check normalizeSpaces("   ") == ""
  let outcome = check(stringOf("ab  ", 0, 15), proc(s: string): bool {.raises: [CatchableError].} =
    isIdempotentAt(normalizeSpaces, s))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-IDEMPOTENCE-02
test "FP-IDEMPOTENCE-02 Given a sorted set, when setInsert twice, then the result equals once, is sorted, unique and holds x":
  let outcome = check(pair(sortedSets(), intIn(-12, 12)), proc(p: (seq[int], int)): bool {.raises: [CatchableError].} =
    let (xs, x) = p
    let once = xs.setInsert(x)
    once.setInsert(x) == once and once.isSorted and x in once and
      once.len == xs.len + (if x in xs: 0 else: 1))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-IDEMPOTENCE-03
test "FP-IDEMPOTENCE-03 Given entries (duplicates allowed), when the same upsert is applied twice, then the result equals once, with exactly one entry for the key":
  check upsertByKey(@[Entry(key: "a", value: 1), Entry(key: "a", value: 2)], "a", 3) == @[Entry(key: "a", value: 3)]
  let outcome = check(pair(entries(), pair(pick(["a", "b", "c", "d", "e"]), intIn(-9, 9))),
    proc(p: (seq[Entry], (string, int))): bool {.raises: [CatchableError].} =
      let (es, (k, v)) = p
      let once = es.upsertByKey(k, v)
      var count = 0
      for e in once:
        if e.key == k:
          inc count
      once.upsertByKey(k, v) == once and count == 1)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-IDEMPOTENCE-04
test "FP-IDEMPOTENCE-04 Given a command, when the same command is applied again, then the ledger is unchanged":
  let c = Command(key: "pay-1", amount: 50)
  let once = initLedger().apply(c).value
  check once.balance == 50
  check once.apply(c) == ok(once, ApplyError)
  check once.hasApplied("pay-1")
  check not once.hasApplied("pay-2")

# SPEC: FP-IDEMPOTENCE-09
test "FP-IDEMPOTENCE-09 Given a used key, when a different amount arrives under it, then keyConflict is reported and nothing changes":
  let once = initLedger().apply(Command(key: "pay-1", amount: 50)).value
  let clash = once.apply(Command(key: "pay-1", amount: 999))
  check clash.isErr
  check clash.error == keyConflict
  check once.balance == 50
  check initLedger().applyAll([Command(key: "a", amount: 1), Command(key: "a", amount: 2)]).error == keyConflict

# SPEC: FP-IDEMPOTENCE-05
test "FP-IDEMPOTENCE-05 Given a batch, when it is replayed in full after itself, then the ledger equals the one from a single run":
  let outcome = check(ledgerCommands(), proc(cs: seq[Command]): bool {.raises: [CatchableError].} =
    let once = initLedger().applyAll(cs)
    once.isOk and initLedger().applyAll(cs & cs) == once and once.value.applyAll(cs) == once)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-IDEMPOTENCE-06
test "FP-IDEMPOTENCE-06 Given commands with distinct keys, when applied in any permutation, then the ledger is the same":
  # A permutation is drawn by giving every command a random sort key and sorting by it.
  let outcome = check(seqOf(pair(intIn(-20, 20), intIn(0, 1000)), 0, 8),
    proc(ps: seq[(int, int)]): bool {.raises: [CatchableError].} =
      var cs: seq[(int, Command)]
      for i, p in ps:
        cs.add (p[1], Command(key: "k" & $i, amount: p[0]))
      var shuffled: seq[Command]
      for item in cs.sortedByIt(it[0]):
        shuffled.add item[1]
      var plain: seq[Command]
      for item in cs:
        plain.add item[1]
      initLedger().applyAll(plain) == initLedger().applyAll(shuffled))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-IDEMPOTENCE-07
test "FP-IDEMPOTENCE-07 Given an operation that is not idempotent, when checked, then the law is found false":
  func bump(x: int): int {.raises: [].} = x + 1
  check not isIdempotentAt(bump, 0)
  let outcome = check(intIn(0, 10), proc(x: int): bool {.raises: [CatchableError].} = isIdempotentAt(bump, x))
  check not outcome.passed

# SPEC: FP-IDEMPOTENCE-08
test "FP-IDEMPOTENCE-08 Given the standard abs, clamp and sorted, when applied twice, then each equals once":
  func absInt(x: int): int {.raises: [].} = abs(x)
  func clamped(x: int): int {.raises: [].} = clamp(x, -5, 5)
  let outcome = check(intIn(-50, 50), proc(x: int): bool {.raises: [CatchableError].} =
    isIdempotentAt(absInt, x) and isIdempotentAt(clamped, x))
  checkpoint describe(outcome)
  check outcome.passed
  let sortedOutcome = check(seqOf(intIn(-9, 9), 0, 10), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    xs.sorted.sorted == xs.sorted)
  checkpoint describe(sortedOutcome)
  check sortedOutcome.passed
