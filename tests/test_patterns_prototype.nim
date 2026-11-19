import std/unittest
import std/options
import propcheck
import nimcs/patterns/prototype

func enemies(): Gen[Enemy] {.raises: [ValueError].} =
  pair(stringOf("abc", 1, 5), pair(intIn(1, 100), seqOf(stringOf("xyz", 1, 3), 0, 4))).map(
    proc(p: (string, (int, seq[string]))): Enemy {.raises: [].} =
      Enemy(kind: p[0], hp: p[1][0], tags: p[1][1]))

# SPEC: GOF-PROTOTYPE-01
test "GOF-PROTOTYPE-01 Given any value, when assigned, then the copy equals it":
  let outcome = check(enemies(), proc(e: Enemy): bool {.raises: [CatchableError].} =
    let c = e
    c == e)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-PROTOTYPE-01
test "GOF-PROTOTYPE-01 Given a copy, when it is changed, then the original is untouched":
  let outcome = check(pair(enemies(), intIn(101, 500)), proc(p: (Enemy, int)): bool {.raises: [CatchableError].} =
    let original = p[0]
    let changed = original.withHp(p[1]).withTag("added")
    changed.hp == p[1] and changed.tags.len == original.tags.len + 1 and
      original == p[0] and original.hp != p[1])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-PROTOTYPE-02
test "GOF-PROTOTYPE-02 Given a registered prototype, when instantiated, then it equals the prototype every time":
  let outcome = check(enemies(), proc(e: Enemy): bool {.raises: [CatchableError].} =
    let reg = initRegistry().register("p", e)
    reg.instantiate("p") == some(e) and reg.instantiate("p") == reg.instantiate("p"))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-PROTOTYPE-02
test "GOF-PROTOTYPE-02 Given an unknown name, when instantiated, then none":
  check initRegistry().instantiate("nope").isNone
  check initRegistry().register("a", Enemy(kind: "k", hp: 1)).instantiate("b").isNone

# SPEC: GOF-PROTOTYPE-03
test "GOF-PROTOTYPE-03 Given an existing name, when registered again, then it is replaced once and others are kept":
  let outcome = check(pair(enemies(), enemies()), proc(p: (Enemy, Enemy)): bool {.raises: [CatchableError].} =
    let r1 = initRegistry().register("a", p[0]).register("b", p[0])
    let r2 = r1.register("a", p[1])
    r2.names == @["a", "b"] and r2.instantiate("a") == some(p[1]) and
      r2.instantiate("b") == some(p[0]) and r1.instantiate("a") == some(p[0]))
  checkpoint describe(outcome)
  check outcome.passed

type
  Shared = ref object
    count: int

  Holder = object
    name: string
    shared: Shared

# SPEC: GOF-PROTOTYPE-04
test "GOF-PROTOTYPE-04 Given an object with a ref field, when copied and the referenced data changes, then the original sees it":
  let original = Holder(name: "a", shared: Shared(count: 1))
  var copy = original
  copy.name = "b"
  copy.shared.count = 99
  check original.name == "a"          # value field: independent
  check original.shared.count == 99   # ref field: shared, the documented caveat
  check original.shared == copy.shared
