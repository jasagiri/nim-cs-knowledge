import std/unittest
import propcheck
import nimcs/patterns/decorator

func core(r: Request): Response {.raises: [].} =
  Response(status: 200, body: "core:" & r.path, trace: @["core"])

let coreHandler: Handler = core

# Four decorators indexed 0..3; the property generators pick indexes so that laws hold for
# every choice, not for one hand-picked pair.
func decorator(i: int): Decorator {.raises: [].} =
  case i mod 4
  of 0: withTrace("t0")
  of 1: withTrace("t1")
  of 2: withBodySuffix("!")
  else: identityDecorator()

func requests(): Gen[Request] {.raises: [ValueError].} =
  pair(stringOf("abc/", 0, 6), stringOf("sk", 0, 2)).map(
    proc(p: (string, string)): Request {.raises: [].} = Request(path: p[0], token: p[1]))

func same(a, b: Handler; r: Request): bool {.raises: [].} =
  a(r) == b(r)

# SPEC: GOF-DECORATOR-01
test "GOF-DECORATOR-01 Given two trace decorators, when composed, then the outer one is first and last":
  let h = compose(withTrace("outer"), withTrace("inner"))(coreHandler)
  check h(Request(path: "p")).trace == @["outer", "inner", "core", "inner/done", "outer/done"]

# SPEC: GOF-DECORATOR-01
test "GOF-DECORATOR-01 Given any two decorators, when composed, then it equals applying the inner then the outer":
  let outcome = check(pair(pair(intIn(0, 3), intIn(0, 3)), requests()),
    proc(p: ((int, int), Request)): bool {.raises: [CatchableError].} =
      let (a, b) = (decorator(p[0][0]), decorator(p[0][1]))
      same(compose(a, b)(coreHandler), a(b(coreHandler)), p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-DECORATOR-02
test "GOF-DECORATOR-02 Given any request, when the identity decorator is applied, then behaviour is unchanged":
  let outcome = check(requests(), proc(r: Request): bool {.raises: [CatchableError].} =
    same(identityDecorator()(coreHandler), coreHandler, r))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-DECORATOR-02
test "GOF-DECORATOR-02 Given any decorator, when composed with the identity on either side, then behaviour is unchanged":
  let outcome = check(pair(intIn(0, 3), requests()), proc(p: (int, Request)): bool {.raises: [CatchableError].} =
    let d = decorator(p[0])
    same(compose(identityDecorator(), d)(coreHandler), d(coreHandler), p[1]) and
      same(compose(d, identityDecorator())(coreHandler), d(coreHandler), p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-DECORATOR-03
test "GOF-DECORATOR-03 Given three decorators, when grouped either way, then behaviour is the same":
  let outcome = check(pair(pair(intIn(0, 3), pair(intIn(0, 3), intIn(0, 3))), requests()),
    proc(p: ((int, (int, int)), Request)): bool {.raises: [CatchableError].} =
      let (a, b, c) = (decorator(p[0][0]), decorator(p[0][1][0]), decorator(p[0][1][1]))
      same(compose(compose(a, b), c)(coreHandler), compose(a, compose(b, c))(coreHandler), p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-DECORATOR-03
test "GOF-DECORATOR-03 Given a list of decorators, when stacked, then the first is outermost":
  let outcome = check(pair(seqOf(intIn(0, 3), 0, 5), requests()), proc(p: (seq[int], Request)): bool {.raises: [CatchableError].} =
    var ds: seq[Decorator] = @[]
    for i in p[0]: ds.add(decorator(i))
    var manual = coreHandler
    for i in countdown(ds.high, 0):
      manual = ds[i](manual)
    same(stack(ds)(coreHandler), manual, p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-DECORATOR-04
test "GOF-DECORATOR-04 Given a wrong token, when handled, then 401 and the inner handler never ran":
  let outcome = check(requests(), proc(r: Request): bool {.raises: [CatchableError].} =
    let h = withAuth("sk")(coreHandler)
    let res = h(r)
    if r.token == "sk":
      res == coreHandler(r)
    else:
      res.status == 401 and res.body == "unauthorized" and "core" notin res.trace)
  checkpoint describe(outcome)
  check outcome.passed
