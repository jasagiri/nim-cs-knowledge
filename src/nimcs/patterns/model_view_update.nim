## Model, view, update (the Elm architecture): state, a pure transition and a pure rendering.
##
## All state is one `Model` value. Everything that can happen is a `Msg` (a closed variant). The
## program is two functions: `update(model, msg): model` says what each message does, and
## `view(model): string` says what the model looks like. Neither performs an effect, so a session
## is a list of messages and nothing else: `replay` folds the list, the same log always gives the
## same model and the same screen, and `trace` gives every intermediate model for time-travel
## debugging and for bug reports that are just a log. The effects (reading keys, drawing the
## string) stay in a thin loop outside. Use it for interactive state with many events (a form, a
## game, an editor buffer); for one value that changes once, a function is enough. The example is
## a counter with a step size and an undo stack.

type
  Model* = object
    count*: int
    step*: int          ## always in `MinStep .. MaxStep`, see `update`
    history*: seq[int]  ## earlier counts, newest last, for `mUndo`

  MsgKind* = enum
    mIncrement, mDecrement, mSetStep, mUndo, mReset

  Msg* = object
    case kind*: MsgKind
    of mSetStep:
      step*: int
    of mIncrement, mDecrement, mUndo, mReset:
      discard

const
  MinStep* = 1
  MaxStep* = 10

func init*(): Model {.raises: [].} = Model(count: 0, step: 1, history: @[])

func increment*(): Msg {.raises: [].} = Msg(kind: mIncrement)
func decrement*(): Msg {.raises: [].} = Msg(kind: mDecrement)
func setStep*(n: int): Msg {.raises: [].} = Msg(kind: mSetStep, step: n)
func undo*(): Msg {.raises: [].} = Msg(kind: mUndo)
func reset*(): Msg {.raises: [].} = Msg(kind: mReset)

func update*(m: Model; msg: Msg): Model {.raises: [].} =
  ## One transition. Total: every model and message gives a model; a step outside the range is
  ## clamped, an undo with nothing to undo changes nothing, and a reset forgets the history.
  case msg.kind
  of mIncrement:
    Model(count: m.count + m.step, step: m.step, history: m.history & m.count)
  of mDecrement:
    Model(count: m.count - m.step, step: m.step, history: m.history & m.count)
  of mSetStep:
    Model(count: m.count, step: min(max(msg.step, MinStep), MaxStep), history: m.history)
  of mUndo:
    if m.history.len == 0: m
    else: Model(count: m.history[^1], step: m.step, history: m.history[0 ..< m.history.high])
  of mReset:
    Model(count: 0, step: m.step, history: @[])

func view*(m: Model): string {.raises: [].} =
  ## The whole screen as text, a function of the model alone.
  "count=" & $m.count & " step=" & $m.step & " undo=" & $m.history.len

func replay*(log: openArray[Msg]; start = init()): Model {.raises: [].} =
  ## The model after the messages, in order, from `start`.
  result = start
  for msg in log:
    result = result.update(msg)

func trace*(log: openArray[Msg]; start = init()): seq[Model] {.raises: [].} =
  ## `log.len + 1` models: the start, then the model after each message.
  var cur = start
  result.add cur
  for msg in log:
    cur = cur.update(msg)
    result.add cur
