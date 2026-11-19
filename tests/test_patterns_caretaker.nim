import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/patterns/caretaker

# The target is an int; the operations a client may run through the forwarder are pure procs on it.
func doubled(t: int): int {.noSideEffect, raises: [].} = t * 2
func negated(t: int): int {.noSideEffect, raises: [].} = -t
func same(t: int): int {.noSideEffect, raises: [].} = t

const ops = [doubled, negated, same]

# SPEC: PAT-CARETAKER-01
test "PAT-CARETAKER-01 Given a forwarder that has not been revoked, when an operation is run through it, then the result is the operation applied to the target":
  let outcome = check(pair(intIn(-100, 100), intIn(0, 2)), proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let w = initCaretaker[int](1).wrap(x[0])
    w.caretaker.forward(w.forwarder, ops[x[1]]) == ok(ops[x[1]](x[0]), CaretakerError))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-CARETAKER-02
test "PAT-CARETAKER-02 Given a revoked forwarder, when any operation is run through it any number of times, then it fails with the revoked error":
  let outcome = check(pair(intIn(-100, 100), seqOf(intIn(0, 2), 0, 8)), proc(x: (int, seq[int])): bool {.raises: [CatchableError].} =
    let w = initCaretaker[int](1).wrap(x[0])
    let c = w.caretaker.revoke(w.revoker).value
    var allRevoked = true
    for k in x[1]:
      if c.forward(w.forwarder, ops[k]) != err(int, crRevoked): allRevoked = false
    allRevoked and c.isRevoked(w.forwarder) and c.liveCount == 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-CARETAKER-03
test "PAT-CARETAKER-03 Given a revoker, when it is used once or many times, then the caretaker behaves the same":
  let outcome = check(pair(intIn(-100, 100), intIn(1, 5)), proc(x: (int, int)): bool {.raises: [CatchableError].} =
    let w = initCaretaker[int](1).wrap(x[0])
    let once = w.caretaker.revoke(w.revoker).value
    var many = w.caretaker
    var allOk = true
    for _ in 1 .. x[1]:
      let r = many.revoke(w.revoker)
      if r.isErr: allOk = false else: many = r.value
    allOk and once.isRevoked(w.forwarder) == many.isRevoked(w.forwarder) and
      once.liveCount == many.liveCount and
      once.forward(w.forwarder, doubled) == many.forward(w.forwarder, doubled))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-CARETAKER-04
test "PAT-CARETAKER-04 Given several forwarders of one caretaker, when one is revoked, then the others keep working and a revoker only revokes its own forwarder":
  let first = initCaretaker[int](1).wrap(10)
  let second = first.caretaker.wrap(20)
  let third = second.caretaker.wrap(10)          # the same target again: still its own slot
  let c = third.caretaker.revoke(second.revoker).value
  check c.forward(first.forwarder, same) == ok(10, CaretakerError)
  check c.forward(second.forwarder, same) == err(int, crRevoked)
  check c.forward(third.forwarder, same) == ok(10, CaretakerError)
  check c.liveCount == 2

# SPEC: PAT-CARETAKER-05
test "PAT-CARETAKER-05 Given capabilities of another caretaker, when they are used here, then forwarding and revoking both fail with the foreign error":
  let mine = initCaretaker[int](1).wrap(5)
  let other = initCaretaker[int](2).wrap(5)
  check mine.caretaker.forward(other.forwarder, same) == err(int, crForeign)
  check mine.caretaker.revoke(other.revoker).error == crForeign
  # Refused, so nothing was revoked.
  check mine.caretaker.forward(mine.forwarder, same) == ok(5, CaretakerError)
  check mine.caretaker.liveCount == 1

# SPEC: PAT-CARETAKER-06
test "PAT-CARETAKER-06 Given revocation as a state change, when the caretaker is revoked, then the earlier caretaker value is unchanged":
  let w = initCaretaker[int](1).wrap(3)
  let revoked = w.caretaker.revoke(w.revoker).value
  check revoked.forward(w.forwarder, same) == err(int, crRevoked)
  check w.caretaker.forward(w.forwarder, same) == ok(3, CaretakerError)
  check not w.caretaker.isRevoked(w.forwarder)
  check not compiles(Forwarder())
  check not compiles(Revoker(brand: 0, slot: 0))
