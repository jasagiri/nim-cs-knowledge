import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/patterns/dependency_record

const today = 10

func fixedClock(day: int): Clock {.raises: [].} =
  result = proc(): int {.raises: [].} = day

func invoicesOf(raw: seq[(int, bool)]): seq[Invoice] {.raises: [].} =
  for i, (due, isPaid) in raw:
    result.add Invoice(id: i, customer: "c" & $i, dueDay: due, paid: isPaid)

func invoiceGen(): Gen[seq[Invoice]] {.raises: [ValueError].} =
  seqOf(pair(intIn(0, 20), boolean()), 0, 12).map(invoicesOf)

func overdue(invoices: seq[Invoice]; day: int): seq[Invoice] {.raises: [].} =
  for inv in invoices:
    if not inv.paid and inv.dueDay < day: result.add inv

# SPEC: PAT-DEPENDENCYRECORD-01
test "PAT-DEPENDENCYRECORD-01 Given recording fakes, when reminders run, then one message per overdue invoice goes out in order":
  let outcome = check(invoiceGen(), proc(invoices: seq[Invoice]): bool {.raises: [CatchableError].} =
    var sent: seq[(string, string)]
    let deps = Deps(now: fixedClock(today), send: proc(to, body: string): Result[int, string] {.raises: [].} =
      sent.add (to, body)
      ok(sent.len, string))
    let r = remindOverdue(deps, invoices)
    let due = overdue(invoices, today)
    if r.isErr or r.value.len != due.len or sent.len != due.len: return false
    for i, inv in due:
      if sent[i][0] != inv.customer or
          sent[i][1] != "Invoice " & $inv.id & " was due on day " & $inv.dueDay or
          r.value[i] != i + 1:
        return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-DEPENDENCYRECORD-02
test "PAT-DEPENDENCYRECORD-02 Given a sender that fails on its kth call, when reminders run, then the error and the ids already sent are returned and no later invoice is tried":
  let outcome = check(pair(invoiceGen(), intIn(1, 6)), proc(p: (seq[Invoice], int)): bool {.raises: [CatchableError].} =
    var calls = 0
    let failAt = p[1]
    let deps = Deps(now: fixedClock(today), send: proc(to, body: string): Result[int, string] {.raises: [].} =
      calls += 1
      if calls == failAt: err(int, "smtp down") else: ok(calls, string))
    let r = remindOverdue(deps, p[0])
    let due = overdue(p[0], today).len
    if due >= failAt:
      var expectedIds: seq[int]
      for i in 1 ..< failAt: expectedIds.add i
      r.isErr and r.error.reason == "smtp down" and calls == failAt and r.error.sentIds == expectedIds
    else:
      r.isOk and calls == due)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-DEPENDENCYRECORD-03
test "PAT-DEPENDENCYRECORD-03 Given a clock replaced with withClock, when reminders run, then only the clock differs and the sender is the same":
  var sent = 0
  let counting = Deps(now: fixedClock(today), send: proc(to, body: string): Result[int, string] {.raises: [].} =
    sent += 1
    ok(sent, string))
  let invoices = @[Invoice(id: 1, customer: "a", dueDay: 5, paid: false),
                   Invoice(id: 2, customer: "b", dueDay: 15, paid: false),
                   Invoice(id: 3, customer: "c", dueDay: 5, paid: true)]
  check remindOverdue(counting, invoices).value.len == 1
  check remindOverdue(counting.withClock(fixedClock(0)), invoices).value.len == 0
  check remindOverdue(counting.withClock(fixedClock(100)), invoices).value.len == 2
  check sent == 3

# SPEC: PAT-DEPENDENCYRECORD-03
test "PAT-DEPENDENCYRECORD-03 Given paid or not yet due invoices, when reminders run, then nothing is sent":
  let outcome = check(invoiceGen(), proc(invoices: seq[Invoice]): bool {.raises: [CatchableError].} =
    var sent = 0
    let deps = Deps(now: fixedClock(0), send: proc(to, body: string): Result[int, string] {.raises: [].} =
      sent += 1
      ok(sent, string))
    let r = remindOverdue(deps, invoices)
    r.isOk and r.value.len == 0 and sent == 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-DEPENDENCYRECORD-04
test "PAT-DEPENDENCYRECORD-04 Given the same inputs and equivalent fakes, when run twice, then results and messages are equal":
  let outcome = check(invoiceGen(), proc(invoices: seq[Invoice]): bool {.raises: [CatchableError].} =
    var a, b: seq[string]
    let depsA = Deps(now: fixedClock(today), send: proc(to, body: string): Result[int, string] {.raises: [].} =
      a.add body
      ok(a.len, string))
    let depsB = Deps(now: fixedClock(today), send: proc(to, body: string): Result[int, string] {.raises: [].} =
      b.add body
      ok(b.len, string))
    remindOverdue(depsA, invoices) == remindOverdue(depsB, invoices) and a == b)
  checkpoint describe(outcome)
  check outcome.passed
