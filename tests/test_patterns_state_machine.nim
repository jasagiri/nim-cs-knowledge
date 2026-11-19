import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/patterns/state_machine

func inputsOf(raw: seq[int]): seq[Input] {.raises: [].} =
  let all = [inPay, inShip, inDeliver, inCancel]
  for r in raw: result.add all[r]

func inputSeqs(): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(0, 3), 0, 8)

func hasTransition(s: OrderState; i: Input): bool {.raises: [].} =
  for t in transitions:
    if t.fromState == s and t.input == i: return true
  false

# SPEC: PAT-STATEMACHINE-01
test "PAT-STATEMACHINE-01 Given every row of the table, when stepped, then the machine moves to the row's target":
  for t in transitions:
    let r = step(t.fromState, t.input)
    check r.isOk
    check r.value == t.toState

# SPEC: PAT-STATEMACHINE-02
test "PAT-STATEMACHINE-02 Given any state and input absent from the table, when stepped, then the error names exactly that pair":
  for s in OrderState:
    for i in Input:
      if not hasTransition(s, i):
        let r = step(s, i)
        check r.isErr
        check r.error == TransitionError(state: s, input: i)

# SPEC: PAT-STATEMACHINE-03
test "PAT-STATEMACHINE-03 Given any start and inputs, when run succeeds, then the final state is reachable from the start":
  let outcome = check(pair(intIn(0, 4), inputSeqs()), proc(p: (int, seq[int])): bool {.raises: [CatchableError].} =
    let start = OrderState(p[0])
    let r = run(start, inputsOf(p[1]))
    if r.isOk: r.value in reachable(start) else: true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-STATEMACHINE-03
test "PAT-STATEMACHINE-03 Given the initial state, when reachability is computed, then it contains the start and every state of the order lifecycle":
  check reachable(osCreated) == @[osCreated, osPaid, osShipped, osDelivered, osCancelled]
  check reachable(osShipped) == @[osShipped, osDelivered]
  check reachable(osCancelled) == @[osCancelled]

# SPEC: PAT-STATEMACHINE-04
test "PAT-STATEMACHINE-04 Given a terminal state, when any input arrives, then it is rejected":
  for s in OrderState:
    if s.isTerminal:
      for i in Input:
        check step(s, i).isErr
      check allowedInputs(s).len == 0
  check osDelivered.isTerminal
  check not osCreated.isTerminal

# SPEC: PAT-STATEMACHINE-05
test "PAT-STATEMACHINE-05 Given the table, when checked, then no state and input pair has two rows":
  check isDeterministic()

# SPEC: PAT-STATEMACHINE-06
test "PAT-STATEMACHINE-06 Given two input lists, when run in one go, then it equals running the first then the second":
  let outcome = check(pair(intIn(0, 4), pair(inputSeqs(), inputSeqs())),
    proc(p: (int, (seq[int], seq[int]))): bool {.raises: [CatchableError].} =
      let start = OrderState(p[0])
      let a = inputsOf(p[1][0])
      let b = inputsOf(p[1][1])
      let whole = run(start, a & b)
      let first = run(start, a)
      let split = if first.isOk: run(first.value, b) else: first
      whole == split)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-STATEMACHINE-06
test "PAT-STATEMACHINE-06 Given a failing input in the middle, when run, then the error is the first invalid step":
  let r = run(osCreated, @[inPay, inDeliver, inShip])
  check r.isErr
  check r.error == TransitionError(state: osPaid, input: inDeliver)
