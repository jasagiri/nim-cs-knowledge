import std/[unittest, options]
import propcheck
import nimcs/fp/result
import nimcs/patterns/chain_of_responsibility

type
  Claims = Handler[Claim, Approval]

func claimOf(x: (int, int)): Claim {.raises: [].} =
  Claim(amount: x[0], category: ["travel", "meals"][x[1]])

func claimGen(): Gen[(int, int)] {.raises: [ValueError].} =
  pair(intIn(-5, 12000), intIn(0, 1))

func asChain(limits: seq[int]): seq[Claims] {.raises: [].} =
  for i, l in limits: result.add within("h" & $i, l)

func neverClaims(c: Claim): Option[Approval] {.raises: [].} = never[Claim, Approval](c)

# SPEC: GOF-CHAIN-01
test "GOF-CHAIN-01 Given any chain, when a request is handled, then the answer is the first handler's some":
  let outcome = check(pair(seqOf(intIn(0, 300), 0, 5), claimGen()), proc(p: (seq[int], (int, int))): bool {.raises: [CatchableError].} =
    let chain = asChain(p[0])
    let c = claimOf(p[1])
    var expected = none(Approval)
    for h in chain:
      let r = h(c)
      if r.isSome:
        expected = r
        break
    firstSome(chain, c) == expected)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-CHAIN-02
test "GOF-CHAIN-02 Given an empty chain or no willing handler, when handled, then the result is an Unhandled error":
  let empty = newSeq[Claims]()
  check empty.handle(Claim(amount: 5, category: "meals")).isErr
  check authorityChain().handle(Claim(amount: 10001, category: "travel")).isErr
  check authorityChain().handle(Claim(amount: 0, category: "travel")).isErr

# SPEC: GOF-CHAIN-03
test "GOF-CHAIN-03 Given a chain that answers a request, when handlers are appended, then the answer does not change":
  let outcome = check(pair(seqOf(intIn(0, 300), 1, 4), pair(seqOf(intIn(0, 300), 0, 3), claimGen())), proc(p: (seq[int], (seq[int], (int, int)))): bool {.raises: [CatchableError].} =
    let base = asChain(p[0])
    let c = claimOf(p[1][1])
    let extended = base & asChain(p[1][0])
    let before = firstSome(base, c)
    before.isNone or firstSome(extended, c) == before)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-CHAIN-04
test "GOF-CHAIN-04 Given the authority chain, when claims arrive, then the lowest sufficient authority approves":
  let chain = authorityChain()
  check chain.handle(Claim(amount: 100, category: "meals")).value.by == "clerk"
  check chain.handle(Claim(amount: 101, category: "meals")).value.by == "manager"
  check chain.handle(Claim(amount: 1000, category: "travel")).value.by == "manager"
  check chain.handle(Claim(amount: 1001, category: "travel")).value.by == "director"
  check chain.handle(Claim(amount: 10000, category: "travel")).value.by == "director"

# SPEC: GOF-CHAIN-05
test "GOF-CHAIN-05 Given three handlers, when grouped either way with orElse, then answers are equal (associativity)":
  let outcome = check(pair(pair(intIn(0, 300), pair(intIn(0, 300), intIn(0, 300))), claimGen()), proc(p: ((int, (int, int)), (int, int))): bool {.raises: [CatchableError].} =
    let a = within("a", p[0][0])
    let b = within("b", p[0][1][0])
    let c = within("c", p[0][1][1])
    let claim = claimOf(p[1])
    a.orElse(b).orElse(c)(claim) == a.orElse(b.orElse(c))(claim))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-CHAIN-06
test "GOF-CHAIN-06 Given any handler, when combined with never on either side, then the answer is unchanged (identity)":
  let outcome = check(pair(intIn(0, 300), claimGen()), proc(p: (int, (int, int))): bool {.raises: [CatchableError].} =
    let h = within("h", p[0])
    let n = Claims(neverClaims)
    let c = claimOf(p[1])
    h.orElse(n)(c) == h(c) and n.orElse(h)(c) == h(c))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-CHAIN-07
test "GOF-CHAIN-07 Given a chain and a request, when handled twice, then the answers are identical":
  let outcome = check(claimGen(), proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let c = claimOf(x)
    authorityChain().handle(c) == authorityChain().handle(c))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-CHAIN-08
test "GOF-CHAIN-08 Given a category restriction, when a claim of another category arrives, then the handler passes it on":
  let chain = @[Claims(within("clerk", 100).onlyCategory("meals")), within("manager", 1000)]
  check chain.handle(Claim(amount: 50, category: "meals")).value.by == "clerk"
  check chain.handle(Claim(amount: 50, category: "travel")).value.by == "manager"
