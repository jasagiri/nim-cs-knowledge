import std/[unittest, tables]
import propcheck
import nimcs/fp/monoid

type Counts = Table[string, int]

func ints(): Gen[int] {.raises: [ValueError].} = intIn(-1000, 1000)

func texts(): Gen[string] {.raises: [ValueError].} = stringOf("abc", 0, 5)

func tablesOf(): Gen[Counts] {.raises: [ValueError].} =
  seqOf(pair(pick(["x", "y", "z", "w"]), intIn(-9, 9)), 0, 5).map(
    proc(ps: seq[(string, int)]): Counts {.raises: [].} =
      result = initTable[string, int]()
      for p in ps:
        result[p[0]] = p[1])

func lawsHold[T](m: Monoid[T]; gen: Gen[T]): bool {.raises: [ValueError, CatchableError].} =
  let identity = check(gen, proc(x: T): bool {.raises: [CatchableError].} =
    m.combine(m.empty, x) == x and m.combine(x, m.empty) == x)
  let assoc = check(pair(gen, pair(gen, gen)), proc(t: (T, (T, T))): bool {.raises: [CatchableError].} =
    m.combine(m.combine(t[0], t[1][0]), t[1][1]) == m.combine(t[0], m.combine(t[1][0], t[1][1])))
  identity.passed and assoc.passed

# SPEC: FP-MONOID-01
test "FP-MONOID-01 Given the integer monoids, when identity and associativity are checked, then they hold":
  check lawsHold(sumMonoid(), ints())
  check lawsHold(productMonoid(), intIn(-30, 30))
  check lawsHold(maxMonoid(), ints())
  check lawsHold(minMonoid(), ints())

# SPEC: FP-MONOID-02
test "FP-MONOID-02 Given string and sequence monoids, when identity and associativity are checked, then they hold":
  check lawsHold(stringMonoid(), texts())
  check lawsHold(seqMonoid[int](), seqOf(intIn(-5, 5), 0, 5))

# SPEC: FP-MONOID-03
test "FP-MONOID-03 Given table monoids over sum, when identity and associativity are checked, then they hold":
  check lawsHold(mapMonoid[string, int](sumMonoid()), tablesOf())
  check lawsHold(mapMonoid[string, int](maxMonoid()), tablesOf())

# SPEC: FP-MONOID-04
test "FP-MONOID-04 Given a sequence, when mconcat, then an empty input gives empty and a split gives the same total":
  check mconcat(sumMonoid(), newSeq[int]()) == 0
  check mconcat(productMonoid(), newSeq[int]()) == 1
  check mconcat(maxMonoid(), newSeq[int]()) == low(int)
  check mconcat(maxMonoid(), [3, 9, 2]) == 9
  check mconcat(minMonoid(), [3, 9, 2]) == 2
  check mconcat(stringMonoid(), ["ab", "", "c"]) == "abc"
  let outcome = check(pair(seqOf(ints(), 0, 10), seqOf(ints(), 0, 10)),
    proc(p: (seq[int], seq[int])): bool {.raises: [CatchableError].} =
      let m = sumMonoid()
      m.mconcat(p[0] & p[1]) == m.combine(m.mconcat(p[0]), m.mconcat(p[1])))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-MONOID-05
test "FP-MONOID-05 Given a sequence and a function, when foldMap, then it equals mconcat of the mapped values":
  let outcome = check(seqOf(ints(), 0, 10), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let m = stringMonoid()
    let f = proc(x: int): string {.noSideEffect, raises: [].} = $x & ","
    var mapped: seq[string]
    for x in xs:
      mapped.add f(x)
    m.foldMap(xs, f) == m.mconcat(mapped))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: FP-MONOID-06
test "FP-MONOID-06 Given concatenation, when the operands are swapped, then the result differs, so it is not commutative":
  let m = stringMonoid()
  check m.combine("ab", "c") == "abc"
  check m.combine("c", "ab") == "cab"
  check m.combine("ab", "c") != m.combine("c", "ab")

# SPEC: FP-MONOID-07
test "FP-MONOID-07 Given tables, when merged with a sum monoid, then colliding keys are added and the merge is commutative":
  let m = mapMonoid[string, int](sumMonoid())
  var a = initTable[string, int]()
  a["x"] = 1
  a["y"] = 2
  var b = initTable[string, int]()
  b["y"] = 10
  b["z"] = 5
  let merged = m.combine(a, b)
  check merged["x"] == 1
  check merged["y"] == 12
  check merged["z"] == 5
  check merged.len == 3
  let outcome = check(pair(tablesOf(), tablesOf()), proc(p: (Counts, Counts)): bool {.raises: [CatchableError].} =
    m.combine(p[0], p[1]) == m.combine(p[1], p[0]))
  checkpoint describe(outcome)
  check outcome.passed
