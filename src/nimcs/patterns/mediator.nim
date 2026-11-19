## Mediator: participants never address each other; a pure routing function does.
##
## The OO pattern puts the knowledge of "who talks to whom" into one mediator object so the
## colleagues stay decoupled. In Nim the colleagues are just names in a room value, a message is
## data, and the mediator is `route(room, message)`, which returns the new room and the list of
## deliveries (who receives what). Nothing is sent from inside; the caller performs the deliveries,
## so the whole chat logic is testable without sockets. Use it when many parties interact by rules
## (chat, form-field dependencies, air-traffic hand-offs). Members are kept sorted, so delivery
## order is deterministic.

import std/[algorithm, strutils]
import nimcs/fp/result

type
  MsgKind* = enum
    mkJoin, mkLeave, mkSay, mkWhisper

  Msg* = object
    sender*: string
    case kind*: MsgKind
    of mkJoin, mkLeave: discard
    of mkSay:
      text*: string
    of mkWhisper:
      to*: string
      secret*: string

  Delivery* = object
    to*: string
    body*: string

  Room* = object
    members: seq[string]   ## sorted, no duplicates

  RoomError* = enum
    reAlreadyMember, reNotMember, reNoSuchRecipient, reSelfWhisper

  Routed* = object
    room*: Room
    deliveries*: seq[Delivery]

  RunReport* = object
    room*: Room
    deliveries*: seq[Delivery]
    rejected*: seq[(int, RoomError)]   ## (index in the log, reason)

func `==`*(a, b: Delivery): bool {.raises: [].} = a.to == b.to and a.body == b.body
func `==`*(a, b: Room): bool {.raises: [].} = a.members == b.members
func `==`*(a, b: Routed): bool {.raises: [].} = a.room == b.room and a.deliveries == b.deliveries
func `==`*(a, b: RunReport): bool {.raises: [].} =
  a.room == b.room and a.deliveries == b.deliveries and a.rejected == b.rejected
func `$`*(d: Delivery): string {.raises: [].} = d.to & ": " & d.body
func `$`*(r: Room): string {.raises: [].} = "Room(" & r.members.join(",") & ")"

func join*(name: string): Msg {.raises: [].} = Msg(kind: mkJoin, sender: name)
func leave*(name: string): Msg {.raises: [].} = Msg(kind: mkLeave, sender: name)
func say*(name, text: string): Msg {.raises: [].} = Msg(kind: mkSay, sender: name, text: text)
func whisper*(name, to, text: string): Msg {.raises: [].} =
  Msg(kind: mkWhisper, sender: name, to: to, secret: text)

func emptyRoom*(): Room {.raises: [].} = Room(members: @[])
func members*(r: Room): seq[string] {.raises: [].} = r.members
func has*(r: Room; name: string): bool {.raises: [].} = name in r.members

func route*(room: Room; m: Msg): Result[Routed, RoomError] {.raises: [].} =
  ## The mediator. Joins and leaves are announced to everyone else; a say reaches every member but
  ## the sender; a whisper reaches exactly its recipient.
  case m.kind
  of mkJoin:
    if room.has(m.sender): return err(Routed, reAlreadyMember)
    let next = Room(members: (room.members & m.sender).sorted)
    var ds: seq[Delivery]
    for who in room.members: ds.add Delivery(to: who, body: m.sender & " joined")
    ok(Routed(room: next, deliveries: ds), RoomError)
  of mkLeave:
    if not room.has(m.sender): return err(Routed, reNotMember)
    var rest: seq[string]
    for who in room.members:
      if who != m.sender: rest.add who
    var ds: seq[Delivery]
    for who in rest: ds.add Delivery(to: who, body: m.sender & " left")
    ok(Routed(room: Room(members: rest), deliveries: ds), RoomError)
  of mkSay:
    if not room.has(m.sender): return err(Routed, reNotMember)
    var ds: seq[Delivery]
    for who in room.members:
      if who != m.sender: ds.add Delivery(to: who, body: m.sender & ": " & m.text)
    ok(Routed(room: room, deliveries: ds), RoomError)
  of mkWhisper:
    if not room.has(m.sender): return err(Routed, reNotMember)
    if m.to == m.sender: return err(Routed, reSelfWhisper)
    if not room.has(m.to): return err(Routed, reNoSuchRecipient)
    ok(Routed(room: room, deliveries: @[Delivery(to: m.to,
        body: m.sender & " (private): " & m.secret)]), RoomError)

func runLog*(room: Room; log: openArray[Msg]): RunReport {.raises: [].} =
  ## Routes a whole log. A message the room rejects delivers nothing and leaves the room as it
  ## was; its index and reason are listed in `rejected`, in log order, so nothing is lost.
  result = RunReport(room: room, deliveries: @[], rejected: @[])
  for i, m in log:
    let r = route(result.room, m)
    if r.isOk:
      result.room = r.value.room
      result.deliveries.add r.value.deliveries
    else:
      result.rejected.add (i, r.error)
