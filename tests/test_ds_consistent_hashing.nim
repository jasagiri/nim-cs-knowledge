import std/[unittest, options, strutils]
import propcheck
import nimcs/ds/consistent_hashing

func ringOf(vnodes: int; names: openArray[string]): Ring =
  let r = newRing(vnodes)
  doAssert r.isOk
  result = r.value
  for n in names:
    let added = result.addNode(n)
    doAssert added.isOk
    result = added.value

func keyList(n: int): seq[string] =
  for i in 0 ..< n:
    result.add "key-" & $i

suite "consistent_hashing":
  # SPEC: DS-CONSISTENTHASHING-01
  test "DS-CONSISTENTHASHING-01 Given a ring, when asking for an owner, then an empty ring has none and otherwise the owner is a member and is always the same":
    let outcome = check(pair(seqOf(stringOf("abcdef", 1, 3), 0, 6), seqOf(stringOf("kxyz01", 0, 6), 1, 30)),
      proc(a: (seq[string], seq[string])): bool {.raises: [CatchableError].} =
        let r = ringOf(8, a[0])
        let again = ringOf(8, a[0])
        for k in a[1]:
          let o = r.owner(k)
          if r.len == 0:
            if o.isSome: return false
          elif o.isNone or o.get notin r.nodes or o != again.owner(k): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-CONSISTENTHASHING-02
  test "DS-CONSISTENTHASHING-02 Given nodes added in any order or more than once, when comparing rings, then the ring is the same":
    let outcome = check(pair(seqOf(stringOf("abcde", 1, 2), 0, 8), intIn(1, 6)),
      proc(a: (seq[string], int)): bool {.raises: [CatchableError].} =
        let forward = ringOf(a[1], a[0])
        var backwards: seq[string]
        for i in countdown(a[0].len - 1, 0): backwards.add a[0][i]
        let doubled = ringOf(a[1], a[0] & a[0])
        forward == ringOf(a[1], backwards) and forward == doubled and forward.nodes == doubled.nodes)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-CONSISTENTHASHING-03
  test "DS-CONSISTENTHASHING-03 Given a ring and a new node, when it is added, then the keys that move are exactly the keys the new node owns and no key moves between old nodes":
    let outcome = check(pair(seqOf(stringOf("abcdef", 1, 2), 1, 6), seqOf(stringOf("kxyz0123", 1, 6), 1, 80)),
      proc(a: (seq[string], seq[string])): bool {.raises: [CatchableError].} =
        let before = ringOf(4, a[0])
        let added = before.addNode("NEW")
        if not added.isOk: return false
        let after = added.value
        var moved = 0
        var ownedByNew = 0
        for k in a[1]:
          if after.owner(k) == some("NEW"): inc ownedByNew
          if before.owner(k) != after.owner(k):
            inc moved
            if after.owner(k) != some("NEW"): return false
        moved == ownedByNew)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-CONSISTENTHASHING-04
  test "DS-CONSISTENTHASHING-04 Given a ring, when a node is removed, then only the keys it owned move, and removing an absent node or re-adding the node changes nothing else":
    let outcome = check(pair(seqOf(stringOf("abcdef", 1, 2), 1, 6), seqOf(stringOf("kxyz0123", 1, 6), 1, 80)),
      proc(a: (seq[string], seq[string])): bool {.raises: [CatchableError].} =
        let full = ringOf(4, a[0])
        let victim = full.nodes[0]
        let smaller = full.removeNode(victim)
        if victim in smaller or smaller.len != full.len - 1: return false
        for k in a[1]:
          if full.owner(k) != smaller.owner(k) and full.owner(k) != some(victim): return false
        if full.removeNode("absent#node") != full: return false
        let back = smaller.addNode(victim)
        back.isOk and back.value == full and smaller.removeNode(victim) == smaller)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-CONSISTENTHASHING-05
  test "DS-CONSISTENTHASHING-05 Given a ring, when asking for n owners, then they are distinct, start with the owner, and number min(n, nodes)":
    let outcome = check(pair(seqOf(stringOf("abcdef", 1, 2), 0, 6), pair(intIn(0, 8), seqOf(stringOf("kxyz01", 1, 5), 1, 20))),
      proc(a: (seq[string], (int, seq[string]))): bool {.raises: [CatchableError].} =
        let r = ringOf(5, a[0])
        for k in a[1][1]:
          let list = r.owners(k, a[1][0])
          if list.len != (if a[1][0] < 1: 0 else: min(a[1][0], r.len)): return false
          for i in 0 ..< list.len:
            for j in 0 ..< i:
              if list[i] == list[j]: return false
          if list.len > 0 and some(list[0]) != r.owner(k): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-CONSISTENTHASHING-06
  test "DS-CONSISTENTHASHING-06 Given fixed strings, when hashing, then the values are the pinned ones (the same on every run and platform)":
    check toHex(ringHash("")) == "EFD01F60BA992926"
    check toHex(ringHash("a")) == "82A2A958A9BECE5B"
    check toHex(ringHash("key-1")) == "A002E14B20BB64EC"
    check vnodePosition("a", 0) == ringHash("a#0")

  # SPEC: DS-CONSISTENTHASHING-07
  test "DS-CONSISTENTHASHING-07 Given four nodes with 128 virtual nodes each and 4000 keys, when a fifth node is added, then every node holds 20 to 30 percent and about a fifth of the keys move, where hash mod n moves most":
    let r4 = ringOf(128, ["n1", "n2", "n3", "n4"])
    let r5 = ringOf(128, ["n1", "n2", "n3", "n4", "n5"])
    let keys = keyList(4000)
    for n in r4.nodes:
      var held = 0
      for k in keys:
        if r4.owner(k) == some(n): inc held
      check held in 800 .. 1200
    var moved = 0
    var modMoved = 0
    for k in keys:
      if r4.owner(k) != r5.owner(k): inc moved
      if ringHash(k) mod 4'u64 != ringHash(k) mod 5'u64: inc modMoved
    check moved in 600 .. 1000          # measured: 802, the ideal is 800
    check modMoved > 3000               # measured: 3213

  # SPEC: DS-CONSISTENTHASHING-08
  test "DS-CONSISTENTHASHING-08 Given bad arguments, when building, then a ring needs at least one virtual node and a node needs a name":
    check newRing(0) == err(Ring, reNoVnodes)
    check newRing(-3) == err(Ring, reNoVnodes)
    let r = newRing(2)
    check r.isOk
    check r.value.addNode("") == err(Ring, reEmptyName)
    check r.value.vnodeCount == 2
