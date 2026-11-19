## Persistent FIFO queue made of two lists (a "banker's queue" without laziness).
##
## `front` holds the elements about to leave in order, `rear` holds the newest elements in reverse.
## Pushing conses onto `rear`; popping drops from `front`; when `rear` grows longer than `front`
## the two are joined by reversing `rear` once. Every operation is O(1) amortized when each
## version of the queue is used once (the ephemeral use of a queue). A persistent version that is
## popped many times from the same state can pay the reversal again each time; when that matters
## use a real-time queue or `deque`. Use a queue for breadth-first search, work lists and
## producer/consumer pipelines in functional code.

import std/options
import nimcs/ds/cons_list

type
  BankersQueue*[T] = object
    front: ConsList[T]
    rear: ConsList[T]
    lenFront: int
    lenRear: int

func emptyQueue*[T](): BankersQueue[T] {.raises: [].} =
  BankersQueue[T]()

func len*[T](q: BankersQueue[T]): int {.raises: [].} =
  q.lenFront + q.lenRear

func isEmpty*[T](q: BankersQueue[T]): bool {.raises: [].} =
  q.len == 0

func rebalanced[T](q: BankersQueue[T]): BankersQueue[T] =
  ## Invariant: lenRear <= lenFront, hence `front` is empty only for the empty queue.
  if q.lenRear <= q.lenFront: q
  else:
    BankersQueue[T](front: q.front.append(q.rear.reverse), rear: emptyList[T](),
      lenFront: q.len, lenRear: 0)

func push*[T](q: BankersQueue[T]; x: T): BankersQueue[T] {.raises: [].} =
  ## Enqueue at the back.
  BankersQueue[T](front: q.front, rear: q.rear.cons(x), lenFront: q.lenFront,
    lenRear: q.lenRear + 1).rebalanced

func peek*[T](q: BankersQueue[T]): Option[T] {.raises: [].} =
  ## The element that `pop` removes next.
  q.front.head

func pop*[T](q: BankersQueue[T]): BankersQueue[T] {.raises: [].} =
  ## The queue without its oldest element; the empty queue stays empty.
  if q.isEmpty: q
  else:
    BankersQueue[T](front: q.front.tail, rear: q.rear, lenFront: q.lenFront - 1,
      lenRear: q.lenRear).rebalanced

func toSeq*[T](q: BankersQueue[T]): seq[T] {.raises: [].} =
  ## Elements from oldest to newest.
  q.front.toSeq & q.rear.reverse.toSeq

func fromSeq*[T](items: openArray[T]): BankersQueue[T] {.raises: [].} =
  var q = emptyQueue[T]()
  for x in items:
    q = q.push(x)
  q
