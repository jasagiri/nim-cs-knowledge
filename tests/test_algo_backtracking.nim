import std/[unittest, options, sets, algorithm]
import propcheck
import nimcs/algo/backtracking

func attacks(cols: seq[int]): bool {.raises: [].} =
  for i in 0 ..< cols.len:
    for j in i + 1 ..< cols.len:
      if cols[i] == cols[j] or abs(cols[i] - cols[j]) == j - i:
        return true

func factorial(n: int): int {.raises: [].} =
  result = 1
  for i in 2 .. n:
    result *= i

func choose(n, k: int): int {.raises: [].} =
  if k < 0 or k > n: return 0
  var row = newSeq[int](n + 1)
  row[0] = 1
  for i in 1 .. n:
    for j in countdown(i, 1):
      row[j] += row[j - 1]
  row[k]

func lexLess(a, b: seq[int]): bool {.raises: [].} =
  for i in 0 ..< min(a.len, b.len):
    if a[i] != b[i]:
      return a[i] < b[i]
  a.len < b.len

func isSortedStrictly(xs: seq[seq[int]]): bool {.raises: [].} =
  for i in 1 ..< xs.len:
    if not lexLess(xs[i - 1], xs[i]):
      return false
  true

# SPEC: TECH-BT-GEN-01
test "TECH-BT-GEN-01 Given a tiny tree, when backtracking, then solutions come out in pre-order":
  # States are strings; children append 'a' or 'b' up to length 2; solutions have length >= 1.
  func kids(s: string): seq[string] {.raises: [].} =
    if s.len < 2: @[s & "a", s & "b"] else: @[]
  func accept(s: string): bool {.raises: [].} = s.len >= 1
  check backtrack("", kids, accept) == @["a", "aa", "ab", "b", "ba", "bb"]

# SPEC: TECH-BT-GEN-02
test "TECH-BT-GEN-02 Given the same arguments, when backtracking twice, then the lists are equal and nothing is shared":
  func kids(s: int): seq[int] {.raises: [].} = (if s < 20: @[s * 2 + 1, s * 2 + 2] else: @[])
  func accept(s: int): bool {.raises: [].} = s mod 7 == 0
  let first = backtrack(0, kids, accept)
  check first == backtrack(0, kids, accept)
  check first.len > 0
  func noKids(s: int): seq[int] {.raises: [].} = @[]
  func never(s: int): bool {.raises: [].} = false
  check backtrack(0, noKids, never).len == 0

# SPEC: TECH-BT-GEN-03
test "TECH-BT-GEN-03 Given a tree with solutions, when asking for the first, then it is the head of the full list; none when there is none":
  func kids(s: seq[int]): seq[seq[int]] {.raises: [].} =
    if s.len < 4: @[s & @[0], s & @[1]] else: @[]
  func accept(s: seq[int]): bool {.raises: [].} = s.len == 4 and s[3] == 1
  let all = backtrack(newSeq[int](), kids, accept)
  check firstSolution(newSeq[int](), kids, accept) == some(all[0])
  func never(s: seq[int]): bool {.raises: [].} = false
  check firstSolution(newSeq[int](), kids, never).isNone

# SPEC: TECH-BT-PERM-01
test "TECH-BT-PERM-01 Given n, when generating permutations, then there are n! distinct ones in lexicographic order":
  let outcome = check(intIn(0, 6), proc(n: int): bool {.raises: [CatchableError].} =
    let ps = permutations(n).get
    var uniq = initHashSet[seq[int]]()
    for p in ps:
      uniq.incl p
    ps.len == factorial(n) and uniq.len == ps.len and isSortedStrictly(ps))
  checkpoint describe(outcome)
  check outcome.passed
  check permutations(3).get == @[@[0, 1, 2], @[0, 2, 1], @[1, 0, 2], @[1, 2, 0], @[2, 0, 1], @[2, 1, 0]]
  check permutations(0).get == @[newSeq[int]()]

# SPEC: TECH-BT-PERM-02
test "TECH-BT-PERM-02 Given n, when generating permutations, then each is a rearrangement of 0..n-1":
  for p in permutations(5).get:
    check sorted(p) == @[0, 1, 2, 3, 4]

# SPEC: TECH-BT-PERM-03
test "TECH-BT-PERM-03 Given a size that is negative or above the limit, when generating permutations, then the result is none":
  check permutations(-1).isNone
  check permutations(maxPermutationSize + 1).isNone
  check permutations(maxPermutationSize).get.len == factorial(maxPermutationSize)

# SPEC: TECH-BT-COMB-01
test "TECH-BT-COMB-01 Given n and k, when generating combinations, then there are C(n,k) ascending subsets in lexicographic order":
  let outcome = check(pair(intIn(0, 9), intIn(0, 11)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    let cs = combinations(p[0], p[1]).get
    var shape = true
    for c in cs:
      shape = shape and c.len == p[1] and isSorted(c) and (c.len == 0 or (c[0] >= 0 and c[^1] < p[0]))
      for i in 1 ..< c.len:
        shape = shape and c[i - 1] < c[i]
    shape and cs.len == choose(p[0], p[1]) and isSortedStrictly(cs))
  checkpoint describe(outcome)
  check outcome.passed
  check combinations(4, 2).get == @[@[0, 1], @[0, 2], @[0, 3], @[1, 2], @[1, 3], @[2, 3]]
  check combinations(6, 3).get.len == 20

# SPEC: TECH-BT-COMB-02
test "TECH-BT-COMB-02 Given invalid or oversized arguments, when generating combinations, then none; k > n gives an empty list":
  check combinations(-1, 2).isNone
  check combinations(3, -1).isNone
  check combinations(maxCombinationSize + 1, 2).isNone
  check combinations(3, 5).get.len == 0
  check combinations(3, 0).get == @[newSeq[int]()]

# SPEC: TECH-BT-QUEENS-01
test "TECH-BT-QUEENS-01 Given n, when solving n-queens, then the number of solutions is the known count":
  let known = [1, 1, 0, 0, 2, 10, 4, 40, 92]   # n = 0 .. 8
  for n in 0 .. 8:
    check nQueens(n).get.len == known[n]

# SPEC: TECH-BT-QUEENS-02
test "TECH-BT-QUEENS-02 Given n, when solving n-queens, then every solution is attack-free, distinct and the list is ordered; invalid n gives none":
  for n in 1 .. 7:
    let sols = nQueens(n).get
    for s in sols:
      check s.len == n
      check not attacks(s)
    check isSortedStrictly(sols)
  check nQueens(4).get == @[@[1, 3, 0, 2], @[2, 0, 3, 1]]
  check nQueens(-1).isNone
  check nQueens(maxQueensSize + 1).isNone
