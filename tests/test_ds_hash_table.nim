import std/[unittest, options, tables, algorithm, sequtils]
import propcheck
import std/hashes
import nimcs/ds/hash_table

type
  Clash = object
    ## A key whose hash takes only two values, so entries pile up in long probe runs.
    id: int

func hash(c: Clash): Hash = Hash(c.id mod 2)
func `==`(a, b: Clash): bool = a.id == b.id

proc ops(): Gen[seq[int]] {.raises: [ValueError].} =
  ## op < 40 puts key `op mod 17` with value `op`; otherwise deletes key `op mod 17`.
  seqOf(intIn(0, 59), 0, 90)

suite "hash_table":
  # SPEC: DS-HASHTABLE-01
  test "DS-HASHTABLE-01 Given a table, when a key is put twice, then get returns the latest value and len counts the key once":
    let t = emptyTable[string, int]().put("a", 1).put("b", 2).put("a", 3)
    check t.get("a") == some(3)
    check t.get("b") == some(2)
    check t.len == 2

  # SPEC: DS-HASHTABLE-02
  test "DS-HASHTABLE-02 Given a table, when asking for an absent key, then get is none and contains is false":
    let e = emptyTable[int, int]()
    check e.get(1).isNone
    check not e.contains(1)
    check e.isEmpty
    let t = e.put(1, 10)
    check t.contains(1)
    check t.get(2).isNone

  # SPEC: DS-HASHTABLE-03
  test "DS-HASHTABLE-03 Given a table, when deleting a key, then it is gone, the others stay, and a missing key changes nothing":
    let t = fromPairs([(1, 10), (2, 20), (3, 30)])
    let d = t.del(2)
    check d.get(2).isNone
    check d.sortedPairs == @[(1, 10), (3, 30)]
    check d.len == 2
    check d.del(99).sortedPairs == d.sortedPairs
    check emptyTable[int, int]().del(1).isEmpty

  # SPEC: DS-HASHTABLE-04
  test "DS-HASHTABLE-04 Given random puts and deletes, when compared with std/tables, then both hold the same entries":
    let outcome = check(ops(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        var t = emptyTable[int, int]()
        var model = initTable[int, int]()
        for op in xs:
          if op < 40:
            t = t.put(op mod 17, op)
            model[op mod 17] = op
          else:
            t = t.del(op mod 17)
            model.del(op mod 17)
          if t.sortedPairs != toSeq(model.pairs).sorted: return false
          if t.len != model.len: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-HASHTABLE-05
  test "DS-HASHTABLE-05 Given a table, when putting or deleting, then the old version is unchanged":
    let t = fromPairs([(1, 10), (2, 20)])
    let a = t.put(3, 30)
    let b = t.del(1)
    let c = t.put(1, 99)
    check t.sortedPairs == @[(1, 10), (2, 20)]
    check a.len == 3 and b.len == 1
    check c.get(1) == some(99)

  # SPEC: DS-HASHTABLE-06
  test "DS-HASHTABLE-06 Given random puts and deletes, when checking the layout, then the probe-run invariants hold at every step":
    let outcome = check(ops(),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        var t = emptyTable[int, int]()
        for op in xs:
          t = if op < 40: t.put(op mod 17, op) else: t.del(op mod 17)
          if not t.invariantsHold: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-HASHTABLE-07
  test "DS-HASHTABLE-07 Given a thousand keys, when they are all put, then every key is found and the table grew":
    var pairs: seq[(int, int)]
    for i in 0 ..< 1000:
      pairs.add (i * 7919, i)
    let t = fromPairs(pairs)
    check t.len == 1000
    check t.invariantsHold
    check pairs.allIt(t.get(it[0]) == some(it[1]))
    check t.get(1).isNone

  # SPEC: DS-HASHTABLE-08
  test "DS-HASHTABLE-08 Given the same entries in any insertion order, when listing sortedPairs, then the lists are equal":
    let outcome = check(seqOf(intIn(0, 40), 0, 30),
      proc(xs: seq[int]): bool {.raises: [CatchableError].} =
        let forward = fromPairs(xs.mapIt((it, it * 2)))
        let backward = fromPairs(xs.reversed.mapIt((it, it * 2)))
        forward.sortedPairs == backward.sortedPairs and forward.len == backward.len)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-HASHTABLE-09
  test "DS-HASHTABLE-09 Given a repeated key, when built with fromPairs, then the last pair wins":
    let t = fromPairs([("k", 1), ("j", 5), ("k", 2)])
    check t.get("k") == some(2)
    check t.len == 2
    check fromPairs(newSeq[(int, int)]()).isEmpty

  # SPEC: DS-HASHTABLE-10
  test "DS-HASHTABLE-10 Given keys that all hash to two home slots, when deleting any key, then the rest are still found":
    let keys = (0 ..< 5).toSeq.mapIt(Clash(id: it))
    let t = fromPairs(keys.mapIt((it, it.id + 1)))
    check t.invariantsHold
    for victim in keys:
      let d = t.del(victim)
      check d.invariantsHold
      check keys.allIt(it == victim or d.get(it) == some(it.id + 1))
      check d.get(victim).isNone
