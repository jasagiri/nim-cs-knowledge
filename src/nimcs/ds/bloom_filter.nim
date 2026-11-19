## Bloom filter with value semantics: a compact set that may say "yes" for an absent key but never
## says "no" for a present one.
##
## `add` returns a new filter (the bit array is copied, O(bits / 64)); the old filter is unchanged.
## The `k` bit positions of a key come from two base hashes as `h1 + i * h2` (double hashing), so
## only two hash computations are needed however large `k` is. Both hashes come from `std/hashes`
## on `(salt, key)` pairs and are deterministic; the stride is chosen coprime to the bit count so a
## key sets `min(hashCount, bits)` distinct bits for every bit count. Use it to skip expensive
## lookups for keys that are certainly absent; do not use it when a false positive is unacceptable
## or when you must delete.

import std/[hashes, math, bitops]
import nimcs/fp/result

type
  BloomError* = enum
    beNoBits, beNoHashes, beShapeMismatch
  BloomFilter* = object
    words: seq[uint64]
    bitCount: int
    hashCount: int
    adds: int

func bloomFilter*(bitCount, hashCount: int): Result[BloomFilter, BloomError] {.raises: [].} =
  ## An empty filter of `bitCount` bits using `hashCount` positions per key.
  if bitCount < 1: err(BloomFilter, beNoBits)
  elif hashCount < 1: err(BloomFilter, beNoHashes)
  else:
    ok(BloomFilter(words: newSeq[uint64]((bitCount + 63) div 64), bitCount: bitCount,
      hashCount: hashCount), BloomError)

func bits*(f: BloomFilter): int {.raises: [].} =
  f.bitCount

func hashes*(f: BloomFilter): int {.raises: [].} =
  f.hashCount

func added*(f: BloomFilter): int {.raises: [].} =
  ## Number of `add` calls (repeated keys count each time).
  f.adds

func setBits*(f: BloomFilter): int {.raises: [].} =
  ## Number of bits that are 1.
  for w in f.words:
    result += countSetBits(w)

type Probe = object
  start, stride: int      ## position i is (start + i * stride) mod bitCount

func probeOf[K](f: BloomFilter; key: K): Probe =
  ## The stride is made coprime to the bit count, so the first min(hashCount, bitCount) positions
  ## of a key are distinct for any bit count (an odd stride only guarantees that for powers of two).
  let m = f.bitCount
  var stride = int(uint64(hash((2, key))) mod uint64(m))
  if stride == 0: stride = 1
  while gcd(stride, m) != 1:
    stride = stride mod m + 1          # m > 1 here: gcd(x, 1) is 1, so the loop never runs for m == 1
  Probe(start: int(uint64(hash((1, key))) mod uint64(m)), stride: stride)

func position(f: BloomFilter; p: Probe; i: int): int =
  (p.start + i * p.stride) mod f.bitCount

func add*[K](f: BloomFilter; key: K): BloomFilter {.raises: [].} =
  var words = f.words
  let probe = f.probeOf(key)
  for i in 0 ..< f.hashCount:
    let p = f.position(probe, i)
    words[p div 64] = words[p div 64] or (1'u64 shl (p mod 64))
  BloomFilter(words: words, bitCount: f.bitCount, hashCount: f.hashCount, adds: f.adds + 1)

func mightContain*[K](f: BloomFilter; key: K): bool {.raises: [].} =
  ## False means certainly absent; true means present or a false positive.
  let probe = f.probeOf(key)
  for i in 0 ..< f.hashCount:
    let p = f.position(probe, i)
    if (f.words[p div 64] and (1'u64 shl (p mod 64))) == 0: return false
  true

func merge*(a, b: BloomFilter): Result[BloomFilter, BloomError] {.raises: [].} =
  ## The filter of the union of both key sets; the shapes (bits and hashes) must be equal.
  if a.bitCount != b.bitCount or a.hashCount != b.hashCount:
    err(BloomFilter, beShapeMismatch)
  else:
    var words = a.words
    for i in 0 ..< words.len:
      words[i] = words[i] or b.words[i]
    ok(BloomFilter(words: words, bitCount: a.bitCount, hashCount: a.hashCount,
      adds: a.adds + b.adds), BloomError)

func sameBits*(a, b: BloomFilter): bool {.raises: [].} =
  ## Equal shape and equal bit array (the `added` counters are ignored).
  a.bitCount == b.bitCount and a.hashCount == b.hashCount and a.words == b.words
