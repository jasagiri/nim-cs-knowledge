import std/unittest
import propcheck
import nimcs/patterns/anti_corruption_layer

func orderGen(): Gen[(string, (int, int))] {.raises: [ValueError].} =
  pair(stringOf("abc", 1, 4), pair(intIn(0, 2), intIn(0, 99_999_999_999)))

func orderOf(x: (string, (int, int))): Order {.raises: [].} =
  let o = initOrder(x[0], OrderStatus(x[1][0]), x[1][1])
  doAssert o.isOk
  o.value

func v1Gen(): Gen[(string, (string, string))] {.raises: [ValueError].} =
  pair(stringOf("ab", 0, 2), pair(stringOf("ASXq", 0, 2), stringOf("0123.9-", 0, 7)))

func v1Of(x: (string, (string, string))): ForeignOrderV1 {.raises: [].} =
  ForeignOrderV1(reference: x[0], statusCode: x[1][0], amount: x[1][1])

# SPEC: PAT-ANTICORRUPTIONLAYER-01
test "PAT-ANTICORRUPTIONLAYER-01 Given any inner order, when sent out in either supplier format and translated back, then it is the same order":
  let outcome = check(orderGen(), proc(x: (string, (int, int))): bool {.raises: [CatchableError].} =
    let o = orderOf(x)
    fromV1(toV1(o)) == ok(o, TranslateError) and fromV2(toV2(o)) == ok(o, TranslateError) and
      fromV1(toV1(o)) == fromV2(toV2(o)))
  checkpoint describe(outcome)
  check outcome.passed
  check toV1(orderOf(("a", (0, 1205)))).amount == "12.05"
  check fromV1(ForeignOrderV1(reference: "r", statusCode: "S", amount: "0.07")).value.total == Cents(7)

# SPEC: PAT-ANTICORRUPTIONLAYER-02
test "PAT-ANTICORRUPTIONLAYER-02 Given any supplier record, when translated, then it is a specific refusal or a valid inner order":
  let outcome = check(v1Gen(), proc(x: (string, (string, string))): bool {.raises: [CatchableError].} =
    let r = fromV1(v1Of(x))
    (not r.isOk) or (r.value.id.len > 0 and int(r.value.total) >= 0))
  checkpoint describe(outcome)
  check outcome.passed
  let outcome2 = check(pair(stringOf("ab", 0, 2), pair(stringOf("ACTIVE", 0, 6), intIn(-5, 5))),
      proc(x: (string, (string, int))): bool {.raises: [CatchableError].} =
    let r = fromV2(ForeignOrderV2(orderId: x[0], state: x[1][0], minorUnits: x[1][1]))
    (not r.isOk) or (r.value.id.len > 0 and int(r.value.total) >= 0))
  checkpoint describe(outcome2)
  check outcome2.passed
  check fromV1(ForeignOrderV1(reference: "", statusCode: "A", amount: "1.00")).error == teEmptyId
  check fromV1(ForeignOrderV1(reference: "r", statusCode: "Z", amount: "1.00")).error == teUnknownStatus
  for bad in ["", "1", "1.0", "1.000", ".50", "a.50", "1,50", "-1.00", "1234567890.00"]:
    check fromV1(ForeignOrderV1(reference: "r", statusCode: "A", amount: bad)).error == teBadAmount
  check fromV2(ForeignOrderV2(orderId: "r", state: "active", minorUnits: 1)).error == teUnknownStatus
  check fromV2(ForeignOrderV2(orderId: "r", state: "ACTIVE", minorUnits: -1)).error == teBadAmount

# SPEC: PAT-ANTICORRUPTIONLAYER-03
test "PAT-ANTICORRUPTIONLAYER-03 Given the inner operations, when handed a supplier record, then the compiler refuses":
  let o = orderOf(("a", (0, 100)))
  check compiles(canShip(o))
  check not compiles(canShip(ForeignOrderV1(reference: "a", statusCode: "A", amount: "1.00")))
  check not compiles(canShip(ForeignOrderV2(orderId: "a", state: "ACTIVE", minorUnits: 100)))
  check canShip(o)
  check not canShip(orderOf(("a", (1, 100))))
  check not canShip(orderOf(("a", (0, 0))))

# SPEC: PAT-ANTICORRUPTIONLAYER-04
test "PAT-ANTICORRUPTIONLAYER-04 Given a batch, when translated, then accepted orders keep their order and each refusal is listed with its index":
  let outcome = check(seqOf(v1Gen(), 0, 8), proc(xs: seq[(string, (string, string))]): bool {.raises: [CatchableError].} =
    var batch: seq[ForeignOrderV1] = @[]
    for x in xs: batch.add v1Of(x)
    let t = translateAll(batch, fromV1)
    if t.orders.len + t.refused.len != batch.len: return false
    var next = 0
    var refusedAt = 0
    for i, f in batch:
      let one = fromV1(f)
      if one.isOk:
        if next >= t.orders.len or t.orders[next] != one.value: return false
        inc next
      else:
        if refusedAt >= t.refused.len or t.refused[refusedAt] != (index: i, error: one.error): return false
        inc refusedAt
    true)
  checkpoint describe(outcome)
  check outcome.passed
