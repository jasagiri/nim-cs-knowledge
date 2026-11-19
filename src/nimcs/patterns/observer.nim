## Observer: an event is a value and subscribers are pure reducers folded over it.
##
## The OO pattern keeps a mutable list of callback objects and calls each when the subject changes,
## which hides ordering, mutation and re-entrancy. Here the subject does not exist as an object:
## the application state `S` is a value, an event `E` is a value, and a subscriber is a named pure
## function `proc(state, event): state`. Publishing is a left fold of the subscribers (in
## subscription order) over the state, and the subscriber list is itself an immutable value that
## `subscribe`/`unsubscribe` return a changed copy of. Because a log of events folds the same way,
## replaying it reproduces the state exactly. Use it for reactive state (UI models, audit
## projections). A subscriber that must do I/O belongs in the imperative shell, reading the new
## state after `publish`.

type
  Reducer*[S, E] = proc(state: S; event: E): S {.noSideEffect, raises: [].}

  Subscription*[S, E] = object
    id*: string
    reduce*: Reducer[S, E]

  Bus*[S, E] = object
    subs: seq[Subscription[S, E]]   ## in subscription order

func initBus*[S, E](): Bus[S, E] {.raises: [].} =
  Bus[S, E](subs: @[])

func ids*[S, E](b: Bus[S, E]): seq[string] {.raises: [].} =
  for s in b.subs: result.add s.id

func subscribe*[S, E](b: Bus[S, E]; id: string; reduce: Reducer[S, E]): Bus[S, E] {.raises: [].} =
  ## Adds a subscriber at the end. A subscriber with the same `id` replaces the old one in place
  ## (so subscribing twice with one id is idempotent).
  result = b
  for i in 0 ..< result.subs.len:
    if result.subs[i].id == id:
      result.subs[i] = Subscription[S, E](id: id, reduce: reduce)
      return
  result.subs.add Subscription[S, E](id: id, reduce: reduce)

func unsubscribe*[S, E](b: Bus[S, E]; id: string): Bus[S, E] {.raises: [].} =
  ## Removes the subscriber with `id`; an unknown id changes nothing.
  result = Bus[S, E](subs: @[])
  for s in b.subs:
    if s.id != id: result.subs.add s

func publish*[S, E](b: Bus[S, E]; state: S; event: E): S {.raises: [].} =
  ## Folds every subscriber over `state`, first subscriber first.
  result = state
  for s in b.subs: result = s.reduce(result, event)

func replay*[S, E](b: Bus[S, E]; start: S; log: openArray[E]): S {.raises: [].} =
  ## Publishes the events in order.
  result = start
  for e in log: result = b.publish(result, e)
