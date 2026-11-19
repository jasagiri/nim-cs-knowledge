import std/[unittest, options]
import propcheck
import nimcs/algo/memoization

type IntMemo = Memo[int, int]

func binom(n, k: int): int {.raises: [].} =
  ## C(n, k) from Pascal's triangle, one row at a time; no intermediate product to overflow.
  var row = newSeq[int](n + 1)
  row[0] = 1
  for i in 1 .. n:
    for j in countdown(i, 1):
      row[j] += row[j - 1]
  row[k]

# SPEC: DP-MEMO-01
test "DP-MEMO-01 Given known Fibonacci numbers, when computed bottom-up, then they match":
  check fibTable(0).get == 0
  check fibTable(1).get == 1
  check fibTable(10).get == 55
  check fibTable(50).get == 12586269025
  check fibTable(92).get == 7540113804746346429

# SPEC: DP-MEMO-02
test "DP-MEMO-02 Given any n in range, when computed top-down with a fresh memo, then it equals the bottom-up value":
  let outcome = check(intIn(0, maxFib), proc(n: int): bool {.raises: [CatchableError].} =
    let r = fibMemo(n, initMemo[int, int]())
    r.isSome and r.get.value == fibTable(n).get)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: DP-MEMO-03
test "DP-MEMO-03 Given a memo, when a key is put, then get finds it and the old memo is unchanged":
  let empty = initMemo[int, int]()
  let one = empty.put(7, 49)
  check empty.get(7).isNone
  check empty.len == 0
  check one.get(7) == some(49)
  check one.len == 1
  let two = one.put(7, 50)
  check one.get(7) == some(49)
  check two.get(7) == some(50)
  check two.len == 1

# SPEC: DP-MEMO-04
test "DP-MEMO-04 Given n outside 0..92 or a grid outside the bounds, when computed, then the result is none":
  check fibMemo(-1, initMemo[int, int]()).isNone
  check fibMemo(maxFib + 1, initMemo[int, int]()).isNone
  check fibTable(-1).isNone
  check fibTable(maxFib + 1).isNone
  check gridPathsTable(0, 3).isNone
  check gridPathsTable(3, 0).isNone
  check gridPathsTable(40, 40).isNone
  check gridPathsMemo(0, 3, initMemo[(int, int), int]()).isNone
  check gridPathsMemo(40, 40, initMemo[(int, int), int]()).isNone

# SPEC: DP-MEMO-05
test "DP-MEMO-05 Given a grid, when counting paths top-down and bottom-up, then both equal the binomial coefficient":
  check gridPathsTable(1, 1).get == 1
  check gridPathsTable(3, 3).get == 6
  check gridPathsTable(18, 18).get == 2333606220
  let outcome = check(pair(intIn(1, 20), intIn(1, 20)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    let (rows, cols) = p
    let expected = binom(rows + cols - 2, rows - 1)
    let top = gridPathsMemo(rows, cols, initMemo[(int, int), int]())
    top.isSome and top.get.paths == expected and gridPathsTable(rows, cols).get == expected)
  checkpoint describe(outcome)
  check outcome.passed
  check gridPathsTable(32, 32).get == binom(62, 31)

# SPEC: DP-MEMO-06
test "DP-MEMO-06 Given the memo returned by a call, when the same call is repeated with it, then value and memo are unchanged":
  let first = fibMemo(60, initMemo[int, int]()).get
  let again = fibMemo(60, first.memo).get
  check again.value == first.value
  check again.memo.len == first.memo.len
  let smaller = fibMemo(30, first.memo).get
  check smaller.value == fibTable(30).get
  check smaller.memo.len == first.memo.len

# SPEC: DP-MEMO-07
test "DP-MEMO-07 Given a fresh memo, when computing fib(n), then it stores exactly the sub-problems 2..n":
  let r = fibMemo(50, initMemo[int, int]()).get
  check r.memo.len == 49
  for k in 2 .. 50:
    check r.memo.get(k) == fibTable(k)
  check r.memo.get(1).isNone
