## Transactional outbox: a state change and the messages it must cause are produced as one value.
##
## A service that updates its state and then sends a message can stop between the two: the state
## changed and nobody was told, or the message left and the state did not change. The outbox makes
## the two a single write. `record` returns one `Unit` holding the new state and the outbox with the
## new messages added, and a store that saves a `Unit` in one transaction cannot keep one half
## without the other. A separate relay later delivers the pending messages. It is a pure function
## here: `nextBatch` says what to send, the shell sends, and `settle` takes the delivery results
## and returns the outbox with only the undelivered messages left. A message leaves the outbox
## only when its delivery was reported as successful, so every message is delivered at least once;
## a delivery whose acknowledgement was lost is sent again, so the receiver must be idempotent,
## and the message ids, which are assigned by the outbox and never reused, are the keys it needs
## (see `idempotent_command`, where a repeated key returns the stored answer). Use it wherever
## a database write must cause a message to another system.

type
  Message* = object
    id*: string          ## `<producer>-<sequence>`; unique for the life of the outbox
    topic*: string
    payload*: string

  Outbox* = object
    producer: string
    nextSeq: int
    pending: seq[Message]

  Unit*[S] = object
    ## What one transaction writes: the state and the outbox together.
    state*: S
    outbox*: Outbox

  DeliveryStatus* = enum
    dsDelivered, dsFailed

  Delivery* = object
    id*: string
    status*: DeliveryStatus

func `==`*(a, b: Message): bool {.raises: [].} =
  a.id == b.id and a.topic == b.topic and a.payload == b.payload

func `==`*(a, b: Outbox): bool {.raises: [].} =
  a.producer == b.producer and a.nextSeq == b.nextSeq and a.pending == b.pending

func initOutbox*(producer: string): Outbox {.raises: [].} =
  ## An empty outbox; message ids will be `producer & "-" & $n` for n = 0, 1, 2, ...
  Outbox(producer: producer, nextSeq: 0, pending: @[])

func pending*(o: Outbox): seq[Message] {.raises: [].} = o.pending

func len*(o: Outbox): int {.raises: [].} = o.pending.len

func nextSequence*(o: Outbox): int {.raises: [].} =
  ## The number the next message gets; it only grows, delivery does not lower it.
  o.nextSeq

func initUnit*[S](state: S; outbox: Outbox): Unit[S] {.raises: [].} =
  Unit[S](state: state, outbox: outbox)

func enqueue*(o: Outbox; topic, payload: string): Outbox {.raises: [].} =
  ## Add one message, with the next id, at the end.
  var pending = o.pending
  pending.add Message(id: o.producer & "-" & $o.nextSeq, topic: topic, payload: payload)
  Outbox(producer: o.producer, nextSeq: o.nextSeq + 1, pending: pending)

func record*[S](u: Unit[S]; newState: S; messages: openArray[(string, string)]): Unit[S] {.raises: [].} =
  ## The state change and its messages `(topic, payload)` as one value: the new state, and the
  ## outbox with every message added in order. There is no result that has one without the other.
  var outbox = u.outbox
  for (topic, payload) in messages:
    outbox = outbox.enqueue(topic, payload)
  Unit[S](state: newState, outbox: outbox)

func nextBatch*(o: Outbox; maxCount: int): seq[Message] {.raises: [].} =
  ## The oldest `maxCount` pending messages, in order, for the relay to send. Asking does not
  ## change the outbox: a batch that is never settled is simply offered again.
  let n = max(0, min(maxCount, o.pending.len))
  o.pending[0 ..< n]

func settle*(o: Outbox; results: openArray[Delivery]): Outbox {.raises: [].} =
  ## Remove the messages whose delivery was reported successful; keep the rest, in their order.
  ## An id that is not pending (reported twice, or never ours) changes nothing, so settling the
  ## same results again gives the same outbox.
  var done: seq[string]
  for r in results:
    if r.status == dsDelivered: done.add r.id
  var rest: seq[Message]
  for m in o.pending:
    if m.id notin done: rest.add m
  Outbox(producer: o.producer, nextSeq: o.nextSeq, pending: rest)

func delivery*(id: string; status: DeliveryStatus): Delivery {.raises: [].} =
  Delivery(id: id, status: status)
