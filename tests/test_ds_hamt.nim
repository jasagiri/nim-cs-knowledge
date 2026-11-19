import std/[unittest, options, tables, algorithm, hashes]
import propcheck
import nimcs/ds/hamt

type Crowded = distinct int   ## keys whose hashes collide a lot: only 3 distinct hash values

func `==`(a, b: Crowded): bool {.borrow.}
func `<`(a, b: Crowded): bool {.borrow.}
func hash(k: Crowded): Hash = Hash(int(k) mod 3) * 0x1234_5678_9abc

proc wideKey(): Gen[int] {.raises: [ValueError].} =
  ## Dense keys, keys spread over 2^30, and keys with ten zero low bits (the first two trie levels
  ## agree), so that put, get and remove reach many levels and the level-by-level splitting.
  map(pair(intIn(0, (1 shl 20) - 1), intIn(0, 2)),
    proc(p: (int, int)): int =
      case p[1]
      of 0: p[0] mod 200
      of 1: p[0] shl 10
      else: p[0] * 1021)

suite "hamt":
  # SPEC: DS-HAMT-01
  test "DS-HAMT-01 Given pairs, when put, then get returns the last value of each key and none for absent keys":
    let outcome = check(seqOf(wideKey(), 0, 120),
      proc(ks: seq[int]): bool {.raises: [CatchableError].} =
        var m = emptyHamt[int, int]()
        var model = initTable[int, int]()
        for i, k in ks:
          m = m.put(k, i)
          model[k] = i
        for k in ks:
          for probe in [k, k + 1, k xor 1024, k xor (1 shl 25)]:
            if m.get(probe) != (if probe in model: some(model[probe]) else: none(int)): return false
        m.len == model.len)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-HAMT-02
  test "DS-HAMT-02 Given a map and a key, when removing it, then the key is gone, the others stay and the size drops":
    let outcome = check(pair(seqOf(wideKey(), 0, 60), intIn(0, 59)),
      proc(a: (seq[int], int)): bool {.raises: [CatchableError].} =
        var m = emptyHamt[int, int]()
        for k in a[0]: m = m.put(k, k * 2)
        # remove a present key when there is one, otherwise an absent one
        let victim = if a[0].len > 0: a[0][a[1] mod a[0].len] else: 7
        let r = m.remove(victim)
        if r.get(victim).isSome: return false
        if m.contains(victim) and r.len != m.len - 1: return false
        if not m.contains(victim) and r.len != m.len: return false
        for k in a[0]:
          if k != victim and r.get(k) != some(k * 2): return false
        r.remove(victim).len == r.len)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-HAMT-03
  test "DS-HAMT-03 Given a map, when putting or removing, then the old map is unchanged":
    let m = fromPairs([(1, "a"), (2, "b")])
    let p = m.put(3, "c").put(1, "z")
    let r = m.remove(1)
    check m.toSortedSeq == @[(1, "a"), (2, "b")]
    check p.toSortedSeq == @[(1, "z"), (2, "b"), (3, "c")]
    check r.toSortedSeq == @[(2, "b")]

  # SPEC: DS-HAMT-04
  test "DS-HAMT-04 Given keys inserted in any order, when listing with toSortedSeq, then the result is sorted by key and independent of insertion order":
    let outcome = check(seqOf(wideKey(), 0, 80),
      proc(ks: seq[int]): bool {.raises: [CatchableError].} =
        var a = emptyHamt[int, int]()
        var b = emptyHamt[int, int]()
        for k in ks: a = a.put(k, 0)
        for k in ks.reversed: b = b.put(k, 0)
        let la = a.toSortedSeq
        la == b.toSortedSeq and la.len == a.len and
          la.isSorted(proc(x, y: (int, int)): int = cmp(x[0], y[0])))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-HAMT-05
  test "DS-HAMT-05 Given keys with colliding hashes, when put, read and removed, then every key stays distinct and reachable":
    var m = emptyHamt[Crowded, int]()
    for i in 0 ..< 300:
      m = m.put(Crowded(i), i)
    check m.len == 300
    for i in 0 ..< 300:
      check m.get(Crowded(i)) == some(i)
    for i in 0 ..< 300:
      if i mod 2 == 0: m = m.remove(Crowded(i))
    check m.len == 150
    for i in 0 ..< 300:
      check m.get(Crowded(i)) == (if i mod 2 == 0: none(int) else: some(i))

  # SPEC: DS-HAMT-06
  test "DS-HAMT-06 Given the empty map, when reading or removing, then get is none and remove changes nothing":
    let m = emptyHamt[string, int]()
    check m.get("x").isNone
    check m.remove("x").len == 0
    check m.toSortedSeq.len == 0
    check default(Hamt[string, int]).put("k", 1).get("k") == some(1)

  # SPEC: DS-HAMT-07
  test "DS-HAMT-07 Given string keys, when put and read, then lookup agrees with a table model":
    let outcome = check(seqOf(stringOf("abc", 0, 5), 0, 60),
      proc(ks: seq[string]): bool {.raises: [CatchableError].} =
        var m = emptyHamt[string, int]()
        var model = initTable[string, int]()
        for i, k in ks:
          m = m.put(k, i)
          model[k] = i
        for k in ks:
          if m.get(k) != some(model[k]): return false
        m.len == model.len)
    checkpoint describe(outcome)
    check outcome.passed
