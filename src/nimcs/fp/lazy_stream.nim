## Lazy streams: sequences that compute their elements only when asked (ADR-NCK-0002 S3, S4).
##
## A `Stream[T]` is an immutable value holding a function that, when pulled, returns either "done"
## or "this element and the rest of the stream". `map`, `filter`, `take` and `takeWhile` build a new
## stream without computing anything and without building a `seq`; only `toSeq(limit)` walks the
## stream. Because a stream never changes, it can be walked twice with the same result, and an
## infinite stream (`iterate`) is safe as long as it is cut with `take` or `toSeq`'s limit.

type
  StreamStep[T] = object
    case hasValue: bool
    of true:
      head: T
      rest: Stream[T]
    of false:
      discard

  Stream*[T] = object
    pull: proc(): StreamStep[T] {.noSideEffect, raises: [].}

func endStep[T](): StreamStep[T] {.raises: [].} =
  StreamStep[T](hasValue: false)

func stepOf[T](head: T; rest: Stream[T]): StreamStep[T] {.raises: [].} =
  StreamStep[T](hasValue: true, head: head, rest: rest)

func emptyStream*[T](): Stream[T] {.raises: [].} =
  ## A stream with no elements.
  result = Stream[T](pull: proc(): StreamStep[T] {.noSideEffect, raises: [].} = endStep[T]())

type
  Shared[T] = ref object
    ## An immutable block of elements that all the stages of one `fromSeq` stream point to,
    ## so that moving to the next element copies a pointer, not the elements (ADR S3: `ref`
    ## only to immutable data).
    items: seq[T]

func fromShared[T](block0: Shared[T]; start: int): Stream[T] {.raises: [].} =
  result = Stream[T](pull: proc(): StreamStep[T] {.noSideEffect, raises: [].} =
    if start >= block0.items.len: endStep[T]()
    else: stepOf(block0.items[start], fromShared(block0, start + 1)))

func fromSeq*[T](xs: openArray[T]): Stream[T] {.raises: [].} =
  ## The stream of the elements of `xs`, in order. The elements are copied once, here.
  fromShared(Shared[T](items: @xs), 0)

func iterate*[T](seed: T; next: proc(x: T): T {.noSideEffect, raises: [].}): Stream[T] {.raises: [].} =
  ## The infinite stream `seed, next(seed), next(next(seed)), ...`. `next` is applied only when
  ## the element after `seed` is pulled, never ahead of need.
  result = Stream[T](pull: proc(): StreamStep[T] {.noSideEffect, raises: [].} =
    let rest = Stream[T](pull: proc(): StreamStep[T] {.noSideEffect, raises: [].} =
      iterate(next(seed), next).pull())
    stepOf(seed, rest))

func map*[T, U](s: Stream[T]; f: proc(x: T): U {.noSideEffect, raises: [].}): Stream[U] {.raises: [].} =
  ## Applies `f` to each element when it is reached.
  result = Stream[U](pull: proc(): StreamStep[U] {.noSideEffect, raises: [].} =
    let step = s.pull()
    if step.hasValue: stepOf(f(step.head), step.rest.map(f))
    else: endStep[U]())

func filter*[T](s: Stream[T]; keep: proc(x: T): bool {.noSideEffect, raises: [].}): Stream[T] {.raises: [].} =
  ## The elements for which `keep` holds. On an infinite stream with no match, pulling never returns.
  result = Stream[T](pull: proc(): StreamStep[T] {.noSideEffect, raises: [].} =
    var cur = s
    while true:
      let step = cur.pull()
      if not step.hasValue:
        return endStep[T]()
      if keep(step.head):
        return stepOf(step.head, step.rest.filter(keep))
      cur = step.rest
    endStep[T]())

func take*[T](s: Stream[T]; n: Natural): Stream[T] {.raises: [].} =
  ## At most the first `n` elements.
  result = Stream[T](pull: proc(): StreamStep[T] {.noSideEffect, raises: [].} =
    if n == 0:
      return endStep[T]()
    let step = s.pull()
    if step.hasValue: stepOf(step.head, step.rest.take(n - 1))
    else: endStep[T]())

func takeWhile*[T](s: Stream[T]; keep: proc(x: T): bool {.noSideEffect, raises: [].}): Stream[T] {.raises: [].} =
  ## The longest prefix whose elements all satisfy `keep`.
  result = Stream[T](pull: proc(): StreamStep[T] {.noSideEffect, raises: [].} =
    let step = s.pull()
    if step.hasValue and keep(step.head): stepOf(step.head, step.rest.takeWhile(keep))
    else: endStep[T]())

func toSeq*[T](s: Stream[T]; limit: Natural): seq[T] {.raises: [].} =
  ## Walks the stream and collects at most `limit` elements. The limit is required so that an
  ## infinite stream cannot hang the caller.
  var cur = s
  while result.len < limit:
    let step = cur.pull()
    if not step.hasValue:
      break
    result.add step.head
    cur = step.rest
