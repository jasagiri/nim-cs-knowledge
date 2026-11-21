import std/unittest
import propcheck
import nimcs/patterns/introduce_parameter_object

type Raw = (seq[(int, (int, bool))], (int, (int, (int, (bool, int)))))

proc raws(): Gen[Raw] {.raises: [ValueError].} =
  pair(seqOf(pair(intIn(0, 100), pair(intIn(0, 5), boolean())), 0, 10),
    pair(intIn(0, 100), pair(intIn(0, 100), pair(intIn(0, 5), pair(boolean(), intIn(0, 4))))))

func products(xs: seq[(int, (int, bool))]): seq[Product] {.raises: [].} =
  for i, x in xs: result.add Product(id: i, price: x[0], rating: x[1][0], inStock: x[1][1])

func filterOf(x: (int, (int, (int, (bool, int))))): Filter {.raises: [].} =
  var f = noFilter().withPrice(x[0], x[1][0]).withMinRating(x[1][1][0]).limited(x[1][1][1][1])
  if x[1][1][1][0]: f = f.inStockOnly
  f

# SPEC: PAT-INTRODUCEPARAMETEROBJECT-01
test "PAT-INTRODUCEPARAMETEROBJECT-01 Given any products and arguments, when selected loose and with a Filter, then the lists are equal":
  let outcome = check(raws(), proc(x: Raw): bool {.raises: [CatchableError].} =
    let ps = products(x[0])
    let (lo, (hi, (rate, (stock, lim)))) = x[1]
    selectLoose(ps, lo, hi, rate, (if stock: srInStockOnly else: srAny), lim) == ps.select(filterOf(x[1])))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-INTRODUCEPARAMETEROBJECT-02
test "PAT-INTRODUCEPARAMETEROBJECT-02 Given the default filter, when selecting, then every product is returned in order":
  let outcome = check(seqOf(pair(intIn(0, 100), pair(intIn(0, 5), boolean())), 0, 10),
      proc(xs: seq[(int, (int, bool))]): bool {.raises: [CatchableError].} =
    let ps = products(xs)
    ps.select(noFilter()) == ps)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-INTRODUCEPARAMETEROBJECT-03
test "PAT-INTRODUCEPARAMETEROBJECT-03 Given two filters, when narrowed together, then the result is what selecting by both in turn gives (without limits)":
  let outcome = check(pair(raws(), raws()), proc(x: (Raw, Raw)): bool {.raises: [CatchableError].} =
    let ps = products(x[0][0])
    let a = filterOf(x[0][1]).limited(NoLimit)
    let b = filterOf(x[1][1]).limited(NoLimit)
    ps.select(a.narrowedBy(b)) == ps.select(a).select(b) and
      a.narrowedBy(b) == b.narrowedBy(a) and a.narrowedBy(a) == a)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-INTRODUCEPARAMETEROBJECT-04
test "PAT-INTRODUCEPARAMETEROBJECT-04 Given a filter and a stricter one, when selecting, then the stricter result is a subset of the looser":
  let outcome = check(raws(), proc(x: Raw): bool {.raises: [CatchableError].} =
    let ps = products(x[0])
    let loose = filterOf(x[1]).limited(NoLimit)
    let strict = loose.inStockOnly.withMinRating(max(loose.minRating, 3))
    let wide = ps.select(loose)
    for p in ps.select(strict):
      if p notin wide: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-INTRODUCEPARAMETEROBJECT-05
test "PAT-INTRODUCEPARAMETEROBJECT-05 Given a limit, when selecting, then at most that many are returned and zero means no limit":
  let ps = @[Product(id: 0, price: 1, rating: 1, inStock: true), Product(id: 1, price: 2, rating: 1, inStock: true),
             Product(id: 2, price: 3, rating: 1, inStock: true)]
  check ps.select(noFilter().limited(2)).len == 2
  check ps.select(noFilter().limited(NoLimit)).len == 3
  check ps.select(noFilter().limited(2))[1].id == 1
