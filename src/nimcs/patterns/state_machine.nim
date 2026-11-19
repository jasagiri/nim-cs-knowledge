## State machine: the transition table is data, `step` is the only function that reads it.
##
## A finite state machine is a set of states, a set of inputs and a table of allowed
## (state, input) -> state rows. Keeping the table as a constant list, rather than nested `if`s
## spread over the code, lets the same data answer other questions: which states are reachable,
## which are terminal, whether any pair has two rows. `step` returns a `Result`, so a forbidden
## input is a value naming the pair, never an exception. The example is an order lifecycle.

import nimcs/fp/result

type
  OrderState* = enum
    osCreated, osPaid, osShipped, osDelivered, osCancelled

  Input* = enum
    inPay, inShip, inDeliver, inCancel

  Transition* = object
    fromState*: OrderState
    input*: Input
    toState*: OrderState

  TransitionError* = object
    ## The pair the table has no row for.
    state*: OrderState
    input*: Input

const transitions*: seq[Transition] = @[
  Transition(fromState: osCreated, input: inPay, toState: osPaid),
  Transition(fromState: osCreated, input: inCancel, toState: osCancelled),
  Transition(fromState: osPaid, input: inShip, toState: osShipped),
  Transition(fromState: osPaid, input: inCancel, toState: osCancelled),
  Transition(fromState: osShipped, input: inDeliver, toState: osDelivered)]

func step*(state: OrderState; input: Input): Result[OrderState, TransitionError] {.raises: [].} =
  ## The one place the table is read. An absent row is an error that names the pair.
  for t in transitions:
    if t.fromState == state and t.input == input:
      return ok(t.toState, TransitionError)
  err(OrderState, TransitionError(state: state, input: input))

func run*(start: OrderState; inputs: openArray[Input]): Result[OrderState, TransitionError] {.raises: [].} =
  ## Folds `step` over the inputs and stops at the first invalid one.
  var current = start
  for i in inputs:
    let next = current.step(i)
    if next.isErr: return next
    current = next.value
  ok(current, TransitionError)

func allowedInputs*(state: OrderState): seq[Input] {.raises: [].} =
  for t in transitions:
    if t.fromState == state: result.add t.input

func isTerminal*(state: OrderState): bool {.raises: [].} =
  state.allowedInputs.len == 0

func reachable*(start: OrderState): seq[OrderState] {.raises: [].} =
  ## Every state some input sequence can lead to from `start` (including `start`), in the
  ## order of the enum. Computed from the table by repeated expansion.
  var seen: set[OrderState] = {start}
  var grew = true
  while grew:
    grew = false
    for t in transitions:
      if t.fromState in seen and t.toState notin seen:
        seen.incl t.toState
        grew = true
  for s in OrderState:
    if s in seen: result.add s

func isDeterministic*(): bool {.raises: [].} =
  ## True when no (state, input) pair has two rows.
  for i in 0 ..< transitions.len:
    for j in i + 1 ..< transitions.len:
      if transitions[i].fromState == transitions[j].fromState and
          transitions[i].input == transitions[j].input:
        return false
  true
