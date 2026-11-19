import std/[unittest, sequtils, algorithm]
import propcheck
import nimcs/fp/result
import nimcs/patterns/mediator

const names = ["ann", "bob", "cy", "dee"]

# A message is drawn as (kind, (sender index, (recipient index, text index))).
type Raw = (int, (int, (int, int)))

func toMsg(r: Raw): Msg {.raises: [].} =
  let who = names[r[1][0]]
  let other = names[r[1][1][0]]
  let text = "t" & $r[1][1][1]
  case r[0]
  of 0: join(who)
  of 1: leave(who)
  of 2: say(who, text)
  else: whisper(who, other, text)

func rawGen(): Gen[Raw] {.raises: [ValueError].} =
  pair(intIn(0, 3), pair(intIn(0, 3), pair(intIn(0, 3), intIn(0, 2))))

func logOf(rs: seq[Raw]): seq[Msg] {.raises: [].} =
  for r in rs: result.add toMsg(r)

func roomOf(ns: seq[string]): Room {.raises: [].} =
  result = emptyRoom()
  for n in ns:
    result = result.route(join(n)).value.room

# SPEC: GOF-MEDIATOR-01
test "GOF-MEDIATOR-01 Given a room, when a member says something, then every other member gets it once and the sender gets nothing":
  let room = roomOf(@["ann", "bob", "cy"])
  let r = room.route(say("bob", "hi")).value
  check r.deliveries.mapIt(it.to) == @["ann", "cy"]
  check r.deliveries.allIt(it.body == "bob: hi")
  check r.room == room

# SPEC: GOF-MEDIATOR-02
test "GOF-MEDIATOR-02 Given a sender outside the room, when any message is routed, then it fails with reNotMember":
  let room = roomOf(@["ann"])
  check room.route(say("bob", "hi")).error == reNotMember
  check room.route(leave("bob")).error == reNotMember
  check room.route(whisper("bob", "ann", "x")).error == reNotMember

# SPEC: GOF-MEDIATOR-03
test "GOF-MEDIATOR-03 Given a whisper, when routed, then exactly its recipient receives it; bad recipients are refused":
  let room = roomOf(@["ann", "bob", "cy"])
  let r = room.route(whisper("ann", "cy", "psst")).value
  check r.deliveries == @[Delivery(to: "cy", body: "ann (private): psst")]
  check room.route(whisper("ann", "zed", "x")).error == reNoSuchRecipient
  check room.route(whisper("ann", "ann", "x")).error == reSelfWhisper

# SPEC: GOF-MEDIATOR-04
test "GOF-MEDIATOR-04 Given any message log, when routed, then every delivery goes to a member of the room before the message and never to its sender":
  let outcome = check(seqOf(rawGen(), 0, 12), proc(rs: seq[Raw]): bool {.raises: [CatchableError].} =
    var room = emptyRoom()
    for m in logOf(rs):
      let r = room.route(m)
      if r.isErr: continue
      for d in r.value.deliveries:
        if d.to == m.sender: return false
        if not room.has(d.to): return false
      room = r.value.room
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-MEDIATOR-05
test "GOF-MEDIATOR-05 Given a message log, when run twice, then reports are identical (determinism)":
  let outcome = check(seqOf(rawGen(), 0, 12), proc(rs: seq[Raw]): bool {.raises: [CatchableError].} =
    runLog(emptyRoom(), logOf(rs)) == runLog(emptyRoom(), logOf(rs)))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-MEDIATOR-06
test "GOF-MEDIATOR-06 Given joins and leaves, when routed, then members stay sorted without duplicates and double joins fail":
  let outcome = check(seqOf(rawGen(), 0, 12), proc(rs: seq[Raw]): bool {.raises: [CatchableError].} =
    let ms = runLog(emptyRoom(), logOf(rs)).room.members
    ms == ms.sortedByIt(it) and ms.deduplicate == ms)
  checkpoint describe(outcome)
  check outcome.passed
  check roomOf(@["ann"]).route(join("ann")).error == reAlreadyMember

# SPEC: GOF-MEDIATOR-07
test "GOF-MEDIATOR-07 Given a log with an invalid message, when run, then the room is as if the message was absent and the rejection is listed":
  let withBad = runLog(emptyRoom(), [join("ann"), say("zed", "x"), join("bob")])
  let without = runLog(emptyRoom(), [join("ann"), join("bob")])
  check withBad.room == without.room
  check withBad.deliveries == without.deliveries
  check withBad.rejected == @[(1, reNotMember)]

# SPEC: GOF-MEDIATOR-08
test "GOF-MEDIATOR-08 Given a leaving member, when routed, then the others are told and the member is gone":
  let room = roomOf(@["ann", "bob"])
  let r = room.route(leave("ann")).value
  check r.room.members == @["bob"]
  check r.deliveries == @[Delivery(to: "bob", body: "ann left")]
