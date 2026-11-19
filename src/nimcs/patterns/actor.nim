## Actor: behaviour is a pure transition and effects are data (ADR-NCK-0002).
##
## An actor is not an object with a mutable handler. Its whole behaviour is one pure function
## `step(self, state, msg): Reaction` that returns the next state and a list of effects as data:
## send a message to an address, spawn another actor, stop itself. "Become" (changing behaviour)
## is therefore a change of the state value, never the replacement of a handler. A mailbox is a
## persistent FIFO value. Nothing here delivers anything by itself: the host loop (`deliver`,
## `runRounds`) takes one message from a mailbox, calls `step` and applies the effects, so the
## actor can be tested without threads, timers or mocks, and a message log replays to the same
## states. The `System` value in this module is a small, pure reference host (one thread, one
## message at a time, round-robin); a real program replaces it with a host that performs I/O,
## time and scheduling, and keeps `step` unchanged.
##
## `self` is passed to `step` because an actor must be able to put its own address in a message
## (a reply-to, a greeting); it is a constant of the actor, so the transition stays a function of
## its inputs. Spawn gives the child its first message (`greeting`) and the next address; the
## parent learns the child's address because the child tells it (see the details page).

import std/options
import nimcs/ds/bankers_queue

type
  Address* = distinct int
    ## Where a message goes. The host hands them out in order, starting at 0.

  Mailbox*[M] = BankersQueue[M]
    ## A persistent FIFO: posting returns a new mailbox, the old one is unchanged.

  EffectKind* = enum
    efSend, efSpawn, efStop

  Effect*[S, M] = object
    ## A request to the host; performing it is not the actor's business.
    case kind*: EffectKind
    of efSend:
      to*: Address
      msg*: M
    of efSpawn:
      initial*: S
      greeting*: Option[M]
    of efStop:
      discard

  Reaction*[S, M] = object
    state*: S
    effects*: seq[Effect[S, M]]

  Step*[S, M] = proc(self: Address; state: S; msg: M): Reaction[S, M] {.noSideEffect, raises: [].}

  Cell[S, M] = object
    state: S
    mailbox: Mailbox[M]
    alive: bool

  System*[S, M] = object
    ## A pure reference host: the actors (address = position), their mailboxes, the messages
    ## that could not be delivered and the number of deliveries so far.
    behaviour: Step[S, M]
    cells: seq[Cell[S, M]]
    dead: seq[(Address, M)]
    count: int

func `==`*(a, b: Address): bool {.borrow.}
func `$`*(a: Address): string {.borrow.}

func sendTo*[S, M](to: Address; msg: M): Effect[S, M] {.raises: [].} =
  Effect[S, M](kind: efSend, to: to, msg: msg)

func spawnActor*[S, M](initial: S; greeting: Option[M]): Effect[S, M] {.raises: [].} =
  Effect[S, M](kind: efSpawn, initial: initial, greeting: greeting)

func stopSelf*[S, M](): Effect[S, M] {.raises: [].} =
  Effect[S, M](kind: efStop)

func `==`*[S, M](a, b: Effect[S, M]): bool {.raises: [].} =
  if a.kind != b.kind: return false
  case a.kind
  of efSend: a.to == b.to and a.msg == b.msg
  of efSpawn: a.initial == b.initial and a.greeting == b.greeting
  of efStop: true

func `==`*[S, M](a, b: Reaction[S, M]): bool {.raises: [].} =
  a.state == b.state and a.effects == b.effects

func emptyMailbox*[M](): Mailbox[M] {.raises: [].} =
  Mailbox[M](emptyQueue[M]())

func post*[M](box: Mailbox[M]; msg: M): Mailbox[M] {.raises: [].} =
  ## Appends at the back.
  Mailbox[M](BankersQueue[M](box).push(msg))

func take*[M](box: Mailbox[M]): Option[(M, Mailbox[M])] {.raises: [].} =
  ## The oldest message and the mailbox without it; `none` when empty.
  let q = BankersQueue[M](box)
  let head = q.peek
  if head.isNone: none((M, Mailbox[M]))
  else: some((head.get, Mailbox[M](q.pop)))

func pending*[M](box: Mailbox[M]): int {.raises: [].} =
  BankersQueue[M](box).len

func initSystem*[S, M](behaviour: Step[S, M]): System[S, M] {.raises: [].} =
  System[S, M](behaviour: behaviour, cells: @[], dead: @[], count: 0)

func known[S, M](sys: System[S, M]; a: Address): bool =
  int(a) >= 0 and int(a) < sys.cells.len

func addActor*[S, M](sys: System[S, M]; initial: S): (System[S, M], Address) {.raises: [].} =
  ## Adds an actor with an empty mailbox; its address is the number of actors so far.
  var next = sys
  next.cells.add Cell[S, M](state: initial, mailbox: emptyMailbox[M](), alive: true)
  (next, Address(sys.cells.len))

func actorCount*[S, M](sys: System[S, M]): int {.raises: [].} = sys.cells.len

func delivered*[S, M](sys: System[S, M]): int {.raises: [].} =
  ## How many messages the host has handed to an actor.
  sys.count

func isAlive*[S, M](sys: System[S, M]; a: Address): bool {.raises: [].} =
  sys.known(a) and sys.cells[int(a)].alive

func stateOf*[S, M](sys: System[S, M]; a: Address): Option[S] {.raises: [].} =
  if sys.known(a): some(sys.cells[int(a)].state) else: none(S)

func mailboxLen*[S, M](sys: System[S, M]; a: Address): int {.raises: [].} =
  if sys.known(a): sys.cells[int(a)].mailbox.pending else: 0

func deadLetters*[S, M](sys: System[S, M]): seq[(Address, M)] {.raises: [].} =
  ## Messages sent to an unknown or stopped actor, in the order they were refused.
  sys.dead

func isIdle*[S, M](sys: System[S, M]): bool {.raises: [].} =
  ## No live actor has a message waiting.
  for c in sys.cells:
    if c.alive and c.mailbox.pending > 0: return false
  true

func tell*[S, M](sys: System[S, M]; to: Address; msg: M): System[S, M] {.raises: [].} =
  ## Puts `msg` in the mailbox of `to`; a message to an unknown or stopped actor is a dead letter.
  result = sys
  if sys.isAlive(to):
    result.cells[int(to)].mailbox = result.cells[int(to)].mailbox.post(msg)
  else:
    result.dead.add (to, msg)

func apply[S, M](sys: System[S, M]; self: Address; fx: Effect[S, M]): System[S, M] =
  case fx.kind
  of efSend:
    result = sys.tell(fx.to, fx.msg)
  of efSpawn:
    let (grown, child) = sys.addActor(fx.initial)
    result = grown
    if fx.greeting.isSome: result = grown.tell(child, fx.greeting.get)
  of efStop:
    result = sys
    var box = result.cells[int(self)].mailbox
    while true:
      let t = box.take
      if t.isNone: break
      result.dead.add (self, t.get[0])
      box = t.get[1]
    result.cells[int(self)].mailbox = emptyMailbox[M]()
    result.cells[int(self)].alive = false

func deliver*[S, M](sys: System[S, M]; a: Address): System[S, M] {.raises: [].} =
  ## The host's one move: take the oldest message of `a`, call `step`, store the new state and
  ## apply the effects in order. Nothing happens if `a` is unknown, stopped or has no message.
  if not sys.isAlive(a): return sys
  let t = sys.cells[int(a)].mailbox.take
  if t.isNone: return sys
  let (msg, rest) = t.get
  let reaction = sys.behaviour(a, sys.cells[int(a)].state, msg)
  result = sys
  result.cells[int(a)].mailbox = rest
  result.cells[int(a)].state = reaction.state
  inc result.count
  for fx in reaction.effects:
    result = result.apply(a, fx)

func runRounds*[S, M](sys: System[S, M]; budget: int): System[S, M] {.raises: [].} =
  ## Round-robin: each round offers every actor, in address order, one delivery. Stops when the
  ## system is idle or after `budget` deliveries, whichever comes first, so a loop of actors that
  ## message each other forever cannot hang the host.
  result = sys
  let stopAt = sys.count + max(budget, 0)
  while result.count < stopAt and not result.isIdle:
    var a = 0
    while a < result.cells.len and result.count < stopAt:
      result = result.deliver(Address(a))
      inc a

func `==`*[S, M](a, b: System[S, M]): bool {.raises: [].} =
  ## Same actors, states, mailboxes, dead letters and delivery count; the behaviour proc is not
  ## compared.
  if a.cells.len != b.cells.len or a.count != b.count or a.dead != b.dead: return false
  for i in 0 ..< a.cells.len:
    let x = a.cells[i]
    let y = b.cells[i]
    if x.alive != y.alive or x.state != y.state: return false
    if BankersQueue[M](x.mailbox).toSeq != BankersQueue[M](y.mailbox).toSeq: return false
  true
