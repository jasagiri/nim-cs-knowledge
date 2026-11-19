import std/unittest
import propcheck
import nimcs/patterns/idempotent_command

func commandsOf(raw: seq[(bool, int)]): seq[Command] {.raises: [].} =
  for i, (isDeposit, amount) in raw:
    result.add Command(key: "k" & $i, kind: (if isDeposit: ckDeposit else: ckWithdraw), amount: amount)

func rawGen(): Gen[seq[(bool, int)]] {.raises: [ValueError].} =
  seqOf(pair(boolean(), intIn(0, 50)), 0, 12)

func foldAll(cmds: seq[Command]): Handled {.raises: [].} =
  result = (ledger: initLedger(), response: Response())
  for c in cmds:
    result = result.ledger.handle(c)

func oracle(cmds: seq[Command]): int {.raises: [].} =
  ## Independent model of exactly-once processing: amounts must be positive, a withdrawal needs funds.
  for c in cmds:
    if c.amount <= 0: continue
    case c.kind
    of ckDeposit: result += c.amount
    of ckWithdraw:
      if result >= c.amount: result -= c.amount

func deliveries(cmds: seq[Command]; extra: seq[(int, int)]): seq[Command] {.raises: [].} =
  ## The commands once each in order, with duplicates of an earlier (or the same) command
  ## injected after each position: at-least-once delivery.
  if cmds.len == 0: return @[]
  for i in 0 ..< cmds.len:
    result.add cmds[i]
    for (pos, which) in extra:
      if pos mod cmds.len == i:
        result.add cmds[which mod (i + 1)]

# SPEC: PAT-IDEMPOTENTCOMMAND-01
test "PAT-IDEMPOTENTCOMMAND-01 Given any ledger and command, when the same command is handled again, then ledger and response are unchanged":
  let outcome = check(pair(rawGen(), pair(boolean(), intIn(-5, 50))), proc(p: (seq[(bool, int)], (bool, int))): bool {.raises: [CatchableError].} =
    let base = foldAll(commandsOf(p[0])).ledger
    let c = Command(key: "new", kind: (if p[1][0]: ckDeposit else: ckWithdraw), amount: p[1][1])
    let first = base.handle(c)
    let second = first.ledger.handle(c)
    second.ledger == first.ledger and second.response == first.response)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-IDEMPOTENTCOMMAND-02
test "PAT-IDEMPOTENTCOMMAND-02 Given at-least-once delivery with duplicates, when handled, then the ledger equals exactly-once processing":
  let outcome = check(pair(rawGen(), seqOf(pair(intIn(0, 30), intIn(0, 30)), 0, 15)),
    proc(p: (seq[(bool, int)], seq[(int, int)])): bool {.raises: [CatchableError].} =
      let cmds = commandsOf(p[0])
      foldAll(deliveries(cmds, p[1])).ledger == foldAll(cmds).ledger)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-IDEMPOTENTCOMMAND-03
test "PAT-IDEMPOTENTCOMMAND-03 Given any history, when an earlier command is redelivered, then it gets the response of its first handling":
  let outcome = check(rawGen(), proc(raw: seq[(bool, int)]): bool {.raises: [CatchableError].} =
    let cmds = commandsOf(raw)
    var l = initLedger()
    var firstResponses: seq[Response]
    for c in cmds:
      let h = l.handle(c)
      l = h.ledger
      firstResponses.add h.response
    for i, c in cmds:
      let again = l.handle(c)
      if again.response != firstResponses[i] or again.ledger != l: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-IDEMPOTENTCOMMAND-04
test "PAT-IDEMPOTENTCOMMAND-04 Given commands with distinct keys, when handled, then the balance equals the independent model":
  let outcome = check(rawGen(), proc(raw: seq[(bool, int)]): bool {.raises: [CatchableError].} =
    let cmds = commandsOf(raw)
    let l = foldAll(cmds).ledger
    l.balance == oracle(cmds) and l.entries.len == cmds.len)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-IDEMPOTENTCOMMAND-05
test "PAT-IDEMPOTENTCOMMAND-05 Given a key already used, when a different command arrives with it, then it is a conflict and nothing changes":
  let outcome = check(pair(boolean(), intIn(1, 50)), proc(p: (bool, int)): bool {.raises: [CatchableError].} =
    let kind = if p[0]: ckDeposit else: ckWithdraw
    let c = Command(key: "k", kind: kind, amount: p[1])
    let h = initLedger().handle(c)
    let other = h.ledger.handle(Command(key: "k", kind: kind, amount: p[1] + 1))
    other.response.kind == rkKeyConflict and other.ledger == h.ledger)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-IDEMPOTENTCOMMAND-06
test "PAT-IDEMPOTENTCOMMAND-06 Given a non-positive amount, when handled, then it is refused, the balance is kept and a retry gives the same refusal":
  let outcome = check(pair(boolean(), intIn(-20, 0)), proc(p: (bool, int)): bool {.raises: [CatchableError].} =
    let kind = if p[0]: ckDeposit else: ckWithdraw
    let start = initLedger().handle(Command(key: "seed", kind: ckDeposit, amount: 30)).ledger
    let c = Command(key: "bad", kind: kind, amount: p[1])
    let h = start.handle(c)
    let again = h.ledger.handle(c)
    h.response.kind == rkInvalidAmount and h.ledger.balance == 30 and again.response == h.response)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-IDEMPOTENTCOMMAND-06
test "PAT-IDEMPOTENTCOMMAND-06 Given too little money, when a withdrawal arrives, then it is refused with insufficient funds":
  let start = initLedger().handle(Command(key: "a", kind: ckDeposit, amount: 10)).ledger
  let h = start.handle(Command(key: "b", kind: ckWithdraw, amount: 11))
  check h.response.kind == rkInsufficientFunds
  check h.response.balance == 10
  check h.ledger.balance == 10
