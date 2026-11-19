import std/[options, unittest]
import propcheck
import nimcs/ds/bankers_queue
import nimcs/patterns/actor

# Example domain: an accumulator whose behaviour is a mode in its state ("become" is a state change).
type
  Kind = enum kAdd, kToggle, kReport, kHalt, kSpawnChild, kGreet, kPing
  Msg = object
    kind: Kind
    n: int
    to: Address
  Mode = enum mPlus, mMinus
  Acc = object
    mode: Mode
    total: int
    log: seq[int]       ## payloads in the order they were processed
    greeted: seq[Address]

func `==`(a, b: Msg): bool {.raises: [].} = a.kind == b.kind and a.n == b.n and a.to == b.to
func `==`(a, b: Acc): bool {.raises: [].} =
  a.mode == b.mode and a.total == b.total and a.log == b.log and a.greeted == b.greeted

func add(n: int): Msg {.raises: [].} = Msg(kind: kAdd, n: n)
func fresh(): Acc {.raises: [].} = Acc(mode: mPlus, total: 0, log: @[], greeted: @[])

func step(self: Address; s: Acc; m: Msg): Reaction[Acc, Msg] {.raises: [].} =
  var next = s
  var fx: seq[Effect[Acc, Msg]]
  case m.kind
  of kAdd:
    next.total += (if s.mode == mPlus: m.n else: -m.n)
    next.log.add m.n
  of kToggle:
    next.mode = (if s.mode == mPlus: mMinus else: mPlus)
  of kReport:
    fx.add sendTo[Acc, Msg](m.to, add(s.total))
  of kHalt:
    fx.add stopSelf[Acc, Msg]()
  of kSpawnChild:
    fx.add spawnActor(fresh(), some(Msg(kind: kGreet, to: self)))
  of kGreet:
    next.greeted.add m.to
  of kPing:
    fx.add sendTo[Acc, Msg](m.to, Msg(kind: kPing, to: self))
  Reaction[Acc, Msg](state: next, effects: fx)

func sys0(): System[Acc, Msg] {.raises: [].} = initSystem[Acc, Msg](step)

func addsGen(): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(-9, 9), 0, 20)

func toldAll(s: System[Acc, Msg]; a: Address; ns: seq[int]): System[Acc, Msg] {.raises: [].} =
  result = s
  for n in ns: result = result.tell(a, add(n))

# SPEC: PAT-ACTOR-01
test "PAT-ACTOR-01 Given messages told to two actors in any interleaving, when the host runs them, then each actor processes its own messages in mailbox order":
  let outcome = check(seqOf(pair(intIn(0, 1), intIn(-9, 9)), 0, 24), proc(xs: seq[(int, int)]): bool {.raises: [CatchableError].} =
    var (s, a) = sys0().addActor(fresh())
    let (s2, b) = s.addActor(fresh())
    s = s2
    var forA, forB: seq[int]
    for (who, n) in xs:
      if who == 0:
        s = s.tell(a, add(n))
        forA.add n
      else:
        s = s.tell(b, add(n))
        forB.add n
    s = s.runRounds(1000)
    s.stateOf(a).get.log == forA and s.stateOf(b).get.log == forB)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-ACTOR-02
test "PAT-ACTOR-02 Given a mailbox value, when messages are posted and taken, then they leave in arrival order and older versions are unchanged":
  let outcome = check(addsGen(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    var box = emptyMailbox[int]()
    var versions: seq[Mailbox[int]]
    for x in xs:
      versions.add box
      box = box.post(x)
    var drained: seq[int]
    var cur = box
    while true:
      let t = cur.take
      if t.isNone: break
      drained.add t.get[0]
      cur = t.get[1]
    var oldIntact = true
    for i, v in versions:
      if v.pending != i: oldIntact = false
    drained == xs and oldIntact and cur.pending == 0)
  checkpoint describe(outcome)
  check outcome.passed
  check emptyMailbox[int]().take.isNone

# SPEC: PAT-ACTOR-03
test "PAT-ACTOR-03 Given one message list, when the host runs it twice, then states, effects and dead letters are equal":
  let outcome = check(addsGen(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let (s, a) = sys0().addActor(fresh())
    let run1 = s.toldAll(a, xs).runRounds(1000)
    let run2 = s.toldAll(a, xs).runRounds(1000)
    var same = true
    for n in xs:
      if step(a, fresh(), add(n)) != step(a, fresh(), add(n)): same = false
    run1 == run2 and same)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-ACTOR-04
test "PAT-ACTOR-04 Given a toggle message, when behaviour changes, then it is the state that changed and the same step function handles every message":
  let outcome = check(addsGen(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    # Equal states react equally, so the whole behaviour is in the state value.
    var folded = fresh()
    for n in xs: folded = step(Address(0), folded, add(n)).state
    let (s, a) = sys0().addActor(fresh())
    let ran = s.toldAll(a, xs).runRounds(1000).stateOf(a).get
    ran == folded)
  checkpoint describe(outcome)
  check outcome.passed
  let (s, a) = sys0().addActor(fresh())
  let after = s.tell(a, add(5)).tell(a, Msg(kind: kToggle)).tell(a, add(5)).runRounds(10).stateOf(a).get
  check after.mode == mMinus
  check after.total == 0                 # +5 then -5: the second add was handled by the new mode
  check step(a, after, add(1)) == step(a, after, add(1))

# SPEC: PAT-ACTOR-05
test "PAT-ACTOR-05 Given sends and a stopped or unknown address, when the host runs, then a send reaches the target mailbox and a message to a stopped or unknown address is a dead letter":
  let (s0, a) = sys0().addActor(fresh())
  let (s1, b) = s0.addActor(fresh())
  # a reports its total to b; then b halts; a later report to b is a dead letter.
  var s = s1.tell(a, add(7)).tell(a, Msg(kind: kReport, to: b)).runRounds(100)
  check s.stateOf(b).get.total == 7
  s = s.tell(b, Msg(kind: kHalt)).runRounds(100)
  check not s.isAlive(b)
  s = s.tell(a, Msg(kind: kReport, to: b)).runRounds(100)
  check s.deadLetters == @[(b, add(7))]
  s = s.tell(Address(99), add(1))
  check s.deadLetters.len == 2
  check s.isAlive(a)

# SPEC: PAT-ACTOR-06
test "PAT-ACTOR-06 Given a spawn effect, when the host applies it, then the child gets the next address and its greeting first, and stop turns the rest of its mailbox into dead letters":
  let (s0, a) = sys0().addActor(fresh())
  var s = s0.tell(a, Msg(kind: kSpawnChild)).tell(a, Msg(kind: kSpawnChild)).runRounds(100)
  check s.actorCount == 3
  check s.stateOf(Address(1)).get.greeted == @[a]
  check s.stateOf(Address(2)).get.greeted == @[a]
  s = s.tell(Address(1), Msg(kind: kHalt)).tell(Address(1), add(4)).tell(Address(1), add(5))
  s = s.deliver(Address(1))
  check not s.isAlive(Address(1))
  check s.deadLetters == @[(Address(1), add(4)), (Address(1), add(5))]

# SPEC: PAT-ACTOR-07
test "PAT-ACTOR-07 Given actors that message each other forever, when the host runs with a step budget, then it stops after exactly that many deliveries":
  # A ping answers with a ping to the sender: a never-ending loop.
  let (s0, a) = sys0().addActor(fresh())
  let (s1, b) = s0.addActor(fresh())
  let start = s1.tell(a, Msg(kind: kPing, to: b))
  let outcome = check(intIn(0, 30), proc(budget: int): bool {.raises: [CatchableError].} =
    start.runRounds(budget).delivered == budget)
  checkpoint describe(outcome)
  check outcome.passed
  check start.runRounds(0) == start
