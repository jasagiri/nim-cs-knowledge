## Saga: a sequence of steps, each with a compensation, interpreted as a pure state machine.
##
## A business operation that spans services cannot be one transaction. A saga runs its steps in
## order; when one fails, it undoes the steps that already succeeded by running their compensations
## in reverse order. Here a saga is data: each `SagaStep` names an action and a compensation, both
## `Effect` values that describe what to do and do nothing themselves (as in `functional_core`).
## The interpreter is a value, `Saga`: `nextEffect` says which effect to perform now, the shell
## performs it and reports the result with `feed`, and the returned saga says what comes next. The
## log records every effect asked for and its result, so what ran is data too. `run` is the loop
## with the shell passed in as a function. Assumptions that make this correct, and that the
## tests state: a failed action had no effect (so its own compensation is not run), and a
## compensation must be idempotent because a shell may have to repeat it. A failed compensation
## stops the saga as `soStuck` with the remaining compensations listed; nothing is skipped. Use it
## for multi-step operations across stores or services; see `transactional_outbox` for making one
## step's state change and its messages atomic.

import std/options

type
  Effect* = object
    ## A request for the outside world: what to do (`name`) and with what (`payload`).
    name*: string
    payload*: string

  SagaStep* = object
    name*: string
    action*: Effect
    compensation*: Effect

  Phase = enum
    pForward, pBackward, pFinished, pStuck

  LogKind* = enum
    lkAction, lkCompensation

  LogEntry* = object
    kind*: LogKind
    step*: string
    effect*: Effect
    ok*: bool

  EffectResult* = enum
    erOk, erFailed

  Outcome* = enum
    soRunning     ## more effects are to be performed
    soCompleted   ## every action succeeded
    soCompensated ## an action failed and every earlier step was undone
    soStuck       ## a compensation failed; `pending` lists what is left to undo

  Saga* = object
    steps: seq[SagaStep]
    done: int            ## steps whose action succeeded and are not yet compensated
    phase: Phase
    log: seq[LogEntry]
    failedAt: int        ## index of the failed action; -1 while none failed

  EffectHandler* = proc(e: Effect): EffectResult {.noSideEffect, raises: [].}
    ## The shell, as far as the saga can see it: did the effect succeed?

func `==`*(a, b: Effect): bool {.raises: [].} = a.name == b.name and a.payload == b.payload

func `==`*(a, b: LogEntry): bool {.raises: [].} =
  a.kind == b.kind and a.step == b.step and a.effect == b.effect and a.ok == b.ok

func `==`*(a, b: Saga): bool {.raises: [].} =
  a.steps == b.steps and a.done == b.done and a.phase == b.phase and a.log == b.log and
    a.failedAt == b.failedAt

func `==`*(a, b: SagaStep): bool {.raises: [].} =
  a.name == b.name and a.action == b.action and a.compensation == b.compensation

func effect*(name: string; payload = ""): Effect {.raises: [].} = Effect(name: name, payload: payload)

func step*(name: string; action, compensation: Effect): SagaStep {.raises: [].} =
  SagaStep(name: name, action: action, compensation: compensation)

func start*(steps: openArray[SagaStep]): Saga {.raises: [].} =
  ## A saga about to run its first step; with no steps it is already completed.
  let all = @steps
  Saga(steps: all, done: 0, phase: (if all.len == 0: pFinished else: pForward), log: @[], failedAt: -1)

func outcome*(s: Saga): Outcome {.raises: [].} =
  case s.phase
  of pForward, pBackward: soRunning
  of pStuck: soStuck
  of pFinished:
    if s.failedAt < 0: soCompleted else: soCompensated

func log*(s: Saga): seq[LogEntry] {.raises: [].} = s.log

func nextEffect*(s: Saga): Option[Effect] {.raises: [].} =
  ## The effect to perform now: the action of the next step going forward, or the compensation of
  ## the latest successful step going backward. `none` when the saga has finished or is stuck.
  case s.phase
  of pForward: some(s.steps[s.done].action)
  of pBackward: some(s.steps[s.done - 1].compensation)
  of pFinished, pStuck: none(Effect)

func pending*(s: Saga): seq[Effect] {.raises: [].} =
  ## The compensations still to run, in the order they must run. Empty unless the saga is stuck
  ## or going backward.
  case s.phase
  of pBackward, pStuck:
    for i in countdown(s.done - 1, 0):
      result.add s.steps[i].compensation
  of pForward, pFinished:
    discard

func feed*(s: Saga; res: EffectResult): Saga {.raises: [].} =
  ## Report whether the effect given by `nextEffect` succeeded. On a finished or stuck saga
  ## there is nothing to report on, and the saga is returned unchanged (a repeated report cannot
  ## move it).
  result = s
  let ok = res == erOk
  case s.phase
  of pForward:
    let st = s.steps[s.done]
    result.log.add LogEntry(kind: lkAction, step: st.name, effect: st.action, ok: ok)
    if ok:
      result.done = s.done + 1
      if result.done == s.steps.len: result.phase = pFinished
    else:
      result.failedAt = s.done
      result.phase = if s.done == 0: pFinished else: pBackward
  of pBackward:
    let st = s.steps[s.done - 1]
    result.log.add LogEntry(kind: lkCompensation, step: st.name, effect: st.compensation, ok: ok)
    if ok:
      result.done = s.done - 1
      if result.done == 0: result.phase = pFinished
    else:
      result.phase = pStuck
  of pFinished, pStuck:
    discard

func run*(steps: openArray[SagaStep]; handler: EffectHandler): Saga {.raises: [].} =
  ## The whole loop: ask, let the handler perform, feed the result, until nothing is left to ask.
  ## It ends because every `feed` either advances or finishes the saga.
  result = start(steps)
  while true:
    let e = result.nextEffect
    if e.isNone: break
    result = result.feed(handler(e.get))
