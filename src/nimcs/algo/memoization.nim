## Memoization without hidden state: the table of already computed answers is a value that is
## passed in and handed back, so a call can be repeated, replayed or shared between callers.
##
## Use it when a recursive definition recomputes the same sub-problems (Fibonacci, paths in a
## grid). The top-down form (`fibMemo`, `gridPathsMemo`) threads a `Memo` through the recursion;
## the bottom-up form (`fibTable`, `gridPathsTable`) fills a local table in dependency order.
## Both give the same answers (DP-MEMO-02, DP-MEMO-05). Neither uses a global cache, so a
## function that looks "memoized" from the outside is still a pure function of its arguments.

import std/[options, tables]

type
  Memo*[K, V] = object
    ## Answers already known, keyed by the sub-problem. Never mutated in place by a caller:
    ## `put` returns a new memo.
    cells: Table[K, V]

  FibResult* = object
    ## The answer and the memo to pass to the next call.
    value*: int
    memo*: Memo[int, int]

  GridResult* = object
    paths*: int
    memo*: Memo[(int, int), int]

const
  maxFib* = 92
    ## `fib(93)` does not fit a signed 64-bit integer.
  maxGridSteps* = 64
    ## `rows + cols` up to this bound keeps the path count below `high(int)`.

func initMemo*[K, V](): Memo[K, V] {.raises: [].} =
  Memo[K, V](cells: initTable[K, V]())

func get*[K, V](m: Memo[K, V]; key: K): Option[V] {.raises: [].} =
  ## The stored answer, or none (DP-MEMO-03).
  if m.cells.hasKey(key): some(m.cells.getOrDefault(key)) else: none(V)

func put*[K, V](m: Memo[K, V]; key: K; value: V): Memo[K, V] {.raises: [].} =
  ## A memo that also knows `key`; `m` itself is unchanged (DP-MEMO-03).
  result = m
  result.cells[key] = value

func len*[K, V](m: Memo[K, V]): int {.raises: [].} =
  m.cells.len

func fibStep(n: int; memo: Memo[int, int]): FibResult {.raises: [].} =
  if n < 2:
    return FibResult(value: n, memo: memo)
  let known = memo.get(n)
  if known.isSome:
    return FibResult(value: known.get, memo: memo)
  let a = fibStep(n - 1, memo)
  let b = fibStep(n - 2, a.memo)
  let total = a.value + b.value
  FibResult(value: total, memo: b.memo.put(n, total))

func fibMemo*(n: int; memo: Memo[int, int]): Option[FibResult] {.raises: [].} =
  ## Fibonacci, top-down, threading `memo`. None unless 0 <= n <= `maxFib` (DP-MEMO-04).
  if n < 0 or n > maxFib: none(FibResult)
  else: some(fibStep(n, memo))

func fibTable*(n: int): Option[int] {.raises: [].} =
  ## Fibonacci, bottom-up with two rolling values. None unless 0 <= n <= `maxFib`.
  if n < 0 or n > maxFib:
    return none(int)
  if n == 0:
    return some(0)
  var prev = 0
  var cur = 1
  for _ in 1 ..< n:
    let next = prev + cur
    prev = cur
    cur = next
  some(cur)

func gridStep(r, c: int; memo: Memo[(int, int), int]): GridResult {.raises: [].} =
  if r == 0 or c == 0:
    return GridResult(paths: 1, memo: memo)
  let known = memo.get((r, c))
  if known.isSome:
    return GridResult(paths: known.get, memo: memo)
  let a = gridStep(r - 1, c, memo)
  let b = gridStep(r, c - 1, a.memo)
  let total = a.paths + b.paths
  GridResult(paths: total, memo: b.memo.put((r, c), total))

func gridPathsMemo*(rows, cols: int; memo: Memo[(int, int), int]): Option[GridResult] {.raises: [].} =
  ## Number of right/down paths from the top-left to the bottom-right cell of a `rows` x `cols`
  ## grid, top-down. None unless both are >= 1 and `rows + cols` <= `maxGridSteps`.
  if rows < 1 or cols < 1 or rows + cols > maxGridSteps: none(GridResult)
  else: some(gridStep(rows - 1, cols - 1, memo))

func gridPathsTable*(rows, cols: int): Option[int] {.raises: [].} =
  ## The same count, bottom-up with one rolling row.
  if rows < 1 or cols < 1 or rows + cols > maxGridSteps:
    return none(int)
  var row = newSeq[int](cols)
  for j in 0 ..< cols:
    row[j] = 1
  for _ in 1 ..< rows:
    for j in 1 ..< cols:
      row[j] += row[j - 1]
  some(row[cols - 1])
