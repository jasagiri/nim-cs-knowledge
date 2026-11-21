## Layer 0, the domain: the rules of a task board as pure functions. It imports no other layer.
##
## A `Board` holds tasks and the next id. Every operation returns a new board or the reason it was
## refused; nothing here parses text, prints or knows that a command line exists.

import nimcs/fp/result
export result

type
  Task* = object
    id*: int
    title*: string
    done*: bool

  Board* = object
    tasks*: seq[Task]
    nextId*: int

  DomainError* = enum
    deEmptyTitle, deNoSuchTask

func emptyBoard*(): Board {.raises: [].} = Board(tasks: @[], nextId: 1)

func add*(b: Board; title: string): Result[Board, DomainError] {.raises: [].} =
  if title.len == 0:
    err(Board, deEmptyTitle)
  else:
    ok(Board(tasks: b.tasks & Task(id: b.nextId, title: title, done: false), nextId: b.nextId + 1),
      DomainError)

func complete*(b: Board; id: int): Result[Board, DomainError] {.raises: [].} =
  ## Idempotent: completing a finished task gives the same board.
  var tasks = b.tasks
  for t in tasks.mitems:
    if t.id == id:
      t.done = true
      return ok(Board(tasks: tasks, nextId: b.nextId), DomainError)
  err(Board, deNoSuchTask)
