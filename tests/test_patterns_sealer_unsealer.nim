import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/patterns/sealer_unsealer

# SPEC: PAT-SEALER-01
test "PAT-SEALER-01 Given a matching pair, when a value is sealed and then unsealed, then the same value comes back":
  let outcome = check(pair(intIn(-1000, 1000), stringOf("abc", 0, 6)), proc(x: (int, string)): bool {.raises: [CatchableError].} =
    let (_, s, u) = initMint(7).newPair()
    u.unseal(s.seal(x[0])) == ok(x[0], SealError) and u.unseal(s.seal(x[1])) == ok(x[1], SealError))
  checkpoint describe(outcome)
  check outcome.passed

func pairAt(k: int): (Sealer, Unsealer) {.raises: [].} =
  ## The k-th pair (counting from 0) of a mint started at 1.
  var mint = initMint(1)
  var pair = mint.newPair()
  for _ in 0 ..< k:
    pair = pair[0].newPair()
  (pair[1], pair[2])

# SPEC: PAT-SEALER-02
test "PAT-SEALER-02 Given pairs made by one mint, when a box is opened with another pair's unsealer, then it fails with the wrong-brand error":
  let outcome = check(pair(intIn(0, 5), intIn(0, 5)), proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let (s, _) = pairAt(x[0])
    let (_, u) = pairAt(x[1])
    let opened = u.unseal(s.seal(42))
    if x[0] == x[1]: opened == ok(42, SealError)
    else: opened == err(int, seWrongBrand))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-SEALER-03
test "PAT-SEALER-03 Given a mint threaded through pair creation, when it is started again from the same seed, then the same pairs result and consecutive pairs differ":
  let (m1, s1, u1) = initMint(3).newPair()
  let (_, s2, u2) = m1.newPair()
  let (m1b, s1b, u1b) = initMint(3).newPair()
  let (_, s2b, u2b) = m1b.newPair()
  check u1b.unseal(s1.seal("x")) == ok("x", SealError)
  check u2b.unseal(s2.seal("y")) == ok("y", SealError)
  check u2.unseal(s1b.seal("z")) == err(string, seWrongBrand)
  check u1.unseal(s2b.seal("z")) == err(string, seWrongBrand)

# SPEC: PAT-SEALER-04
test "PAT-SEALER-04 Given the sealed types, when code outside the module tries to forge or inspect them, then it does not compile":
  let (_, s, u) = initMint(1).newPair()
  let box = s.seal(5)
  check not compiles(box.content)
  check not compiles(Box[int](brand: 1, content: 5))
  check not compiles(Sealer())
  check not compiles(Unsealer(brand: 1))
  check not compiles(s.unseal(box))           # the sealer cannot open what it sealed
  check not compiles(u.seal(5))               # the unsealer cannot seal
  check compiles(u.unseal(box))
  check not compiles(u.unseal(s.seal("text")) == ok(5, SealError))   # the content type is kept
