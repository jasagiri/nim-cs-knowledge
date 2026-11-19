import std/[unittest, options]
import propcheck
import nimcs/algo/rabin_karp
import nimcs/algo/number_theory

func naiveFindAll(text, pattern: string): seq[int] {.raises: [].} =
  result = @[]
  if pattern.len > text.len:
    return
  for start in 0 .. text.len - pattern.len:
    if text[start ..< start + pattern.len] == pattern:
      result.add start

func mkParams(base, m: int): HashParams {.raises: [].} =
  params(base, hashModulus(m).get).get

func pairs(): Gen[(string, string)] {.raises: [ValueError].} =
  pair(stringOf("ab", 0, 30), stringOf("ab", 1, 4))

# SPEC: STR-RK-01
test "STR-RK-01 Given any text and width, when rolling the hash, then each window equals a fresh hash of that window":
  let p = mkParams(31, 1_000_003)
  let outcome = check(pair(stringOf("abc", 0, 25), intIn(1, 6)), proc(q: (string, int)): bool {.raises: [CatchableError].} =
    let (text, width) = q
    let rolled = rollingHashes(text, width, p)
    var ok = rolled.len == (if width <= text.len: text.len - width + 1 else: 0)
    for i in 0 ..< rolled.len:
      ok = ok and rolled[i] == hashOf(text[i ..< i + width], p)
    ok)
  checkpoint describe(outcome)
  check outcome.passed
  check hashOf("", p) == 0

# SPEC: STR-RK-02
test "STR-RK-02 Given any text and pattern, when searching with a realistic modulus, then the positions equal the naive search":
  let p = mkParams(257, 1_000_000_007 mod 2_147_483_647)
  let outcome = check(pairs(), proc(q: (string, string)): bool {.raises: [CatchableError].} =
    rkFindAll(q[0], q[1], p) == naiveFindAll(q[0], q[1]))
  checkpoint describe(outcome)
  check outcome.passed
  check rkFindAll("aaaa", "aa", p) == @[0, 1, 2]

# SPEC: STR-RK-03
test "STR-RK-03 Given a tiny modulus with many collisions, when searching, then candidates may be extra but results never are":
  let p = mkParams(2, 3)
  let outcome = check(pairs(), proc(q: (string, string)): bool {.raises: [CatchableError].} =
    let found = rkFindAll(q[0], q[1], p)
    let cands = rkCandidates(q[0], q[1], p)
    var subset = true
    for i in found:
      subset = subset and i in cands
    found == naiveFindAll(q[0], q[1]) and subset and cands.len >= found.len)
  checkpoint describe(outcome)
  check outcome.passed
  # With modulus 3 some window collides with the pattern but differs from it.
  check rkCandidates("abbabab", "abb", p).len > rkFindAll("abbabab", "abb", p).len

# SPEC: STR-RK-04
test "STR-RK-04 Given an empty pattern or one longer than the text, when searching, then the offsets are every position or none":
  let p = mkParams(31, 101)
  check rkFindAll("abc", "", p) == @[0, 1, 2, 3]
  check rkFindAll("ab", "abc", p) == newSeq[int]()
  check rkCandidates("ab", "", p) == newSeq[int]()

# SPEC: STR-RK-05
test "STR-RK-05 Given an invalid modulus or base, when constructing parameters, then the result is none":
  check hashModulus(0).isNone
  check hashModulus(1).isNone
  check hashModulus(-7).isNone
  check hashModulus(maxHashModulus + 1).isNone
  check hashModulus(maxHashModulus).isSome
  check hashModulus(2).isSome
  let m = hashModulus(101).get
  check params(1, m).isNone
  check params(101, m).isNone
  check params(100, m).isSome
  check $m == "101"
  check hashModulusValue(m) == 101

# SPEC: STR-RK-05
test "STR-RK-05 Given both modules imported together, when naming their moduli, then neither clashes with the other":
  let rk = hashModulus(101).get
  let nt = modulus(3_000_000_000).get
  check hashModulusValue(rk) == 101
  check toInt(nt) == 3_000_000_000
  check hashModulus(3_000_000_000).isNone
  check maxHashModulus < maxModulus
