## Recursion and loops in Nim: the accumulator rewrite and when to stop recursing
## (ADR-NCK-0002 S1, S5, S6).
##
## A recursive call is a tail call when it is the last thing a routine does. Nim does not
## guarantee that a tail call reuses the stack frame: whether a C compiler turns it into a jump
## depends on the backend and its settings, so a recursion whose
## depth grows with the input (a list of 100 000 elements, `n = 10^6`) can overflow the stack even
## when written in tail form. The portable rule is: write the recursion to find the invariant,
## carry the partial result in an accumulator argument, then make the final routine a loop with a
## local `var` (invisible outside, ADR S5). Each family here has the naive recursion, the
## accumulator form and the loop, and the tests show that all three agree.

type
  FibIndex* = range[0 .. 92]
    ## `fib(92)` is the largest Fibonacci number that fits in a 64-bit `int`.

func sumToNaive*(n: Natural): int {.raises: [].} =
  ## `0 + 1 + ... + n`, recursing on `n - 1`: the addition happens after the call returns, so the
  ## stack grows by one frame per step. Use only for small `n`.
  if n == 0: 0 else: n + sumToNaive(n - 1)

func sumToAcc*(n: Natural; acc: int): int {.raises: [].} =
  ## `acc + (0 + 1 + ... + n)`, with the partial sum carried in `acc`: the recursive call is the last
  ## action (a tail call), but Nim does not promise to reuse the frame.
  if n == 0: acc else: sumToAcc(n - 1, acc + n)

func sumToLoop*(n: Natural): int {.raises: [].} =
  ## The same sum as a loop with a local accumulator: constant stack for any `n`.
  for i in 1 .. n:
    result += i

func fibNaive*(n: FibIndex): int {.raises: [].} =
  ## Fibonacci by the definition: two recursive calls, time exponential in `n`. Small `n` only.
  if n < 2: int(n) else: fibNaive(n - 1) + fibNaive(n - 2)

func fibAcc*(n: Natural; a, b: int): int {.raises: [].} =
  ## Fibonacci with two accumulators holding `fib(k)` and `fib(k + 1)`: `fibAcc(n, 0, 1)` is
  ## `fib(n)`. A tail call, linear time. It never computes a sum beyond `fib(n)`, so it does not
  ## overflow for `n <= 92`.
  if n == 0: a elif n == 1: b else: fibAcc(n - 1, b, a + b)

func fibLoop*(n: FibIndex): int {.raises: [].} =
  ## The pair of accumulators as two local variables; no sum beyond `fib(n)` is computed.
  if n < 2:
    return int(n)
  var previous = 0
  var current = 1
  for _ in 2 .. n:
    (previous, current) = (current, previous + current)
  current

func gcdRec*(a, b: Natural): int {.raises: [].} =
  ## Euclid's algorithm. Naturally a tail call: nothing is left to do after the recursive call.
  if b == 0: a else: gcdRec(b, a mod b)

func gcdLoop*(a, b: Natural): int {.raises: [].} =
  ## The same algorithm as a loop over two local variables.
  var x: int = a
  var y: int = b
  while y != 0:
    (x, y) = (y, x mod y)
  x
