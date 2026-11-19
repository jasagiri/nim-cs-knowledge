import std/[unittest, times]
import std/options
import propcheck
import nimcs/patterns/flyweight

func words(): Gen[seq[string]] {.raises: [ValueError].} =
  seqOf(stringOf("ab", 0, 3), 0, 12)

func poolOf(items: seq[string]): Pool {.raises: [].} =
  initPool().internAll(items).pool

# SPEC: GOF-FLYWEIGHT-01
test "GOF-FLYWEIGHT-01 Given any pool and string, when interned twice, then symbol and pool are unchanged the second time":
  let outcome = check(pair(words(), stringOf("ab", 0, 3)), proc(p: (seq[string], string)): bool {.raises: [CatchableError].} =
    let (pool1, a) = poolOf(p[0]).intern(p[1])
    let (pool2, b) = pool1.intern(p[1])
    a == b and pool2 == pool1)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-FLYWEIGHT-02
test "GOF-FLYWEIGHT-02 Given any pool and string, when interned and resolved, then the string comes back":
  let outcome = check(pair(words(), stringOf("ab", 0, 3)), proc(p: (seq[string], string)): bool {.raises: [CatchableError].} =
    let (pool, sym) = poolOf(p[0]).intern(p[1])
    pool.resolve(sym) == some(p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-FLYWEIGHT-02
test "GOF-FLYWEIGHT-02 Given an unknown symbol, when resolved, then none":
  check initPool().resolve(Sym(0)).isNone
  check initPool().intern("a").pool.resolve(Sym(1)).isNone
  check initPool().intern("a").pool.resolve(Sym(-1)).isNone

# SPEC: GOF-FLYWEIGHT-03
test "GOF-FLYWEIGHT-03 Given two strings, when interned in one pool, then symbols are equal exactly when strings are":
  let outcome = check(pair(words(), pair(stringOf("ab", 0, 3), stringOf("ab", 0, 3))),
    proc(p: (seq[string], (string, string))): bool {.raises: [CatchableError].} =
      let (pool1, a) = poolOf(p[0]).intern(p[1][0])
      let (_, b) = pool1.intern(p[1][1])
      (a == b) == (p[1][0] == p[1][1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-FLYWEIGHT-04
test "GOF-FLYWEIGHT-04 Given a list of strings, when interned, then size is the distinct count and symbols follow first appearance":
  let outcome = check(words(), proc(xs: seq[string]): bool {.raises: [CatchableError].} =
    let (pool, syms) = initPool().internAll(xs)
    var firsts: seq[string] = @[]
    var expected: seq[Sym] = @[]
    for x in xs:
      let at = firsts.find(x)
      if at < 0:
        expected.add(Sym(firsts.len))
        firsts.add(x)
      else:
        expected.add(Sym(at))
    pool.size == firsts.len and syms == expected)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-FLYWEIGHT-05
test "GOF-FLYWEIGHT-05 Given a non-empty pool and any list, when interned in bulk, then it equals interning one by one":
  let outcome = check(pair(words(), words()), proc(p: (seq[string], seq[string])): bool {.raises: [CatchableError].} =
    let base = poolOf(p[0])
    let bulk = base.internAll(p[1])
    var pool = base
    var syms: seq[Sym] = @[]
    for x in p[1]:
      let (next, sym) = pool.intern(x)
      pool = next
      syms.add(sym)
    bulk.pool == pool and bulk.syms == syms)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-FLYWEIGHT-06
test "GOF-FLYWEIGHT-06 Given 20000 distinct strings, when interned in bulk, then it finishes in linear-looking time":
  var items: seq[string] = @[]
  for i in 0 ..< 20000:
    items.add("item" & $i)
  let started = cpuTime()
  let (pool, syms) = initPool().internAll(items)
  let spent = cpuTime() - started
  check pool.size == 20000
  check syms.len == 20000
  check syms[19999] == Sym(19999)
  check spent < 1.0
