import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/ds/bloom_filter

proc fresh(bits, k: int): BloomFilter =
  let r = bloomFilter(bits, k)
  doAssert r.isOk
  r.value

suite "bloom_filter":
  # SPEC: DS-BLOOM-01
  test "DS-BLOOM-01 Given any added keys, when asking mightContain, then every added key is found (no false negatives)":
    let outcome = check(seqOf(intIn(-1000, 1000), 0, 80),
      proc(ks: seq[int]): bool {.raises: [CatchableError].} =
        var f = fresh(512, 3)
        for k in ks: f = f.add(k)
        for k in ks:
          if not f.mightContain(k): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BLOOM-02
  test "DS-BLOOM-02 Given a filter, when adding a key twice, then the bit array equals adding it once":
    let outcome = check(seqOf(stringOf("abcdef", 1, 6), 0, 30),
      proc(ks: seq[string]): bool {.raises: [CatchableError].} =
        var f = fresh(256, 4)
        for k in ks: f = f.add(k)
        for k in ks:
          if not f.add(k).sameBits(f): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BLOOM-03
  test "DS-BLOOM-03 Given a filter, when adding a key, then the old filter is unchanged":
    let f = fresh(1024, 3)
    let g = f.add("alpha")
    check not f.mightContain("alpha")
    check g.mightContain("alpha")
    check f.added == 0
    check g.added == 1

  # SPEC: DS-BLOOM-04
  test "DS-BLOOM-04 Given two filters of equal shape, when merged, then the result has the same bits as one filter holding all keys, and merge is commutative":
    let outcome = check(pair(seqOf(intIn(0, 500), 0, 40), seqOf(intIn(0, 500), 0, 40)),
      proc(t: (seq[int], seq[int])): bool {.raises: [CatchableError].} =
        var a = fresh(512, 3)
        var b = fresh(512, 3)
        for k in t[0]: a = a.add(k)
        for k in t[1]: b = b.add(k)
        let ab = a.merge(b)
        let ba = b.merge(a)
        if not ab.isOk or not ba.isOk or not ab.value.sameBits(ba.value): return false
        var all = fresh(512, 3)
        for k in t[0] & t[1]: all = all.add(k)
        if not ab.value.sameBits(all): return false      # the filter of the union, bit for bit
        for k in t[0] & t[1]:
          if not ab.value.mightContain(k): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-BLOOM-05
  test "DS-BLOOM-05 Given invalid sizes or mismatched shapes, when constructing or merging, then an error value says why":
    check bloomFilter(0, 3) == err(BloomFilter, beNoBits)
    check bloomFilter(64, 0) == err(BloomFilter, beNoHashes)
    let m = fresh(64, 2).merge(fresh(128, 2))
    check not m.isOk
    check m.error == beShapeMismatch
    check not fresh(64, 2).merge(fresh(64, 3)).isOk

  # SPEC: DS-BLOOM-06
  test "DS-BLOOM-06 Given a well sized filter, when probing absent keys, then false positives are rare":
    var f = fresh(20000, 4)
    for i in 0 ..< 200:
      f = f.add(i)
    var falsePositives = 0
    for i in 1000 ..< 3000:
      if f.mightContain(i): inc falsePositives
    check falsePositives < 40   # 2%; the expected rate here is far below 1%
    check not fresh(64, 2).mightContain(1)

  # SPEC: DS-BLOOM-07
  test "DS-BLOOM-07 Given any bit count including non powers of two, when adding one key, then it sets exactly min(hashes, bits) distinct bits":
    let outcome = check(pair(pair(intIn(1, 40), intIn(1, 12)), intIn(-100_000, 100_000)),
      proc(t: ((int, int), int)): bool {.raises: [CatchableError].} =
        let ((bitCount, k), key) = t
        let f = fresh(bitCount, k).add(key)
        f.setBits == min(k, bitCount) and f.mightContain(key))
    checkpoint describe(outcome)
    check outcome.passed
    for bitCount in [9, 10, 12, 15, 100, 1000]:
      for key in 0 ..< 500:
        check fresh(bitCount, 9).add(key).setBits == 9
