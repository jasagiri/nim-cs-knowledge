## Bit vector: a fixed-size set of the integers 0 ..< n, one bit each, packed into 64-bit words.
##
## The size is part of the value and never changes. Membership, `count` (population count),
## `rank` (how many members are below an index) and `select` (the index of the k-th member) are
## word operations, so a set of n small integers takes n/8 bytes and set algebra (union,
## intersection, difference, complement) runs 64 elements at a time. A `BitVector` is a value:
## `withBit` and `withoutBit` return a new vector and copy n/64 words. Use it when the universe is
## a known range of small integers (flags, visited marks, sieve results, dense id sets). Use
## `std/sets` for sparse or non-integer members, and `bloom_filter` when memory must stay below
## one bit per possible member and a false positive is acceptable (a bit vector never lies).

import std/[options, bitops]

type
  BitVector* = object
    words: seq[uint64]
    nbits: int           ## bits at index >= nbits in the last word are always 0

func wordCount(n: int): int =
  (n + 63) div 64

func bitVector*(size: int): Option[BitVector] {.raises: [].} =
  ## A vector of `size` zero bits; none when `size` is negative.
  if size < 0: none(BitVector)
  else: some(BitVector(words: newSeq[uint64](wordCount(size)), nbits: size))

func len*(v: BitVector): int {.raises: [].} =
  ## Number of bits (the universe size), not the number of set bits; see `count`.
  v.nbits

func test*(v: BitVector; i: int): bool {.raises: [].} =
  ## True when bit `i` is set. An index outside 0 ..< len is not a member, as in a set.
  if i < 0 or i >= v.nbits: false
  else: ((v.words[i div 64] shr (i mod 64)) and 1'u64) == 1'u64

func withBit*(v: BitVector; i: int): Option[BitVector] {.raises: [].} =
  ## `v` with bit `i` set (idempotent); none when `i` is outside 0 ..< len.
  if i < 0 or i >= v.nbits: return none(BitVector)
  var words = v.words
  words[i div 64] = words[i div 64] or (1'u64 shl (i mod 64))
  some(BitVector(words: words, nbits: v.nbits))

func withoutBit*(v: BitVector; i: int): Option[BitVector] {.raises: [].} =
  ## `v` with bit `i` cleared (idempotent); none when `i` is outside 0 ..< len.
  if i < 0 or i >= v.nbits: return none(BitVector)
  var words = v.words
  words[i div 64] = words[i div 64] and not (1'u64 shl (i mod 64))
  some(BitVector(words: words, nbits: v.nbits))

func fromIndices*(size: int; indices: openArray[int]): Option[BitVector] {.raises: [].} =
  ## The vector of `size` bits with exactly `indices` set (duplicates allowed); none when `size` is
  ## negative or an index is out of range.
  let empty = bitVector(size)
  if empty.isNone: return empty
  var words = empty.get.words
  for i in indices:
    if i < 0 or i >= size: return none(BitVector)
    words[i div 64] = words[i div 64] or (1'u64 shl (i mod 64))
  some(BitVector(words: words, nbits: size))

func count*(v: BitVector): int {.raises: [].} =
  ## Number of set bits (population count).
  for w in v.words:
    result += popcount(w)

func rank*(v: BitVector; i: int): Option[int] {.raises: [].} =
  ## Number of set bits among indices 0 ..< i; none unless 0 <= i <= len.
  if i < 0 or i > v.nbits: return none(int)
  var total = 0
  for w in 0 ..< i div 64:
    total += popcount(v.words[w])
  let rest = i mod 64
  if rest > 0:
    total += popcount(v.words[i div 64] and ((1'u64 shl rest) - 1'u64))
  some(total)

func select*(v: BitVector; k: int): Option[int] {.raises: [].} =
  ## Index of the set bit with `k` set bits below it (k = 0 is the smallest member); none when
  ## `k` is negative or at least `count`. `rank(select(k)) == k`.
  if k < 0: return none(int)
  var remaining = k
  for wi in 0 ..< v.words.len:
    let c = popcount(v.words[wi])
    if remaining < c:
      var w = v.words[wi]
      for _ in 0 ..< remaining:
        w = w and (w - 1'u64)           # clear the lowest set bit
      return some(wi * 64 + countTrailingZeroBits(w))
    remaining -= c
  none(int)

func toIndices*(v: BitVector): seq[int] {.raises: [].} =
  ## The set bits as ascending indices.
  for wi in 0 ..< v.words.len:
    var w = v.words[wi]
    while w != 0'u64:
      result.add wi * 64 + countTrailingZeroBits(w)
      w = w and (w - 1'u64)

func combine(a, b: BitVector; f: proc(x, y: uint64): uint64 {.noSideEffect, raises: [].}): Option[BitVector] =
  if a.nbits != b.nbits: return none(BitVector)
  var words = newSeq[uint64](a.words.len)
  for i in 0 ..< words.len:
    words[i] = f(a.words[i], b.words[i])
  some(BitVector(words: words, nbits: a.nbits))

func union*(a, b: BitVector): Option[BitVector] {.raises: [].} =
  ## Bits set in `a` or `b`; none when the sizes differ.
  combine(a, b, proc(x, y: uint64): uint64 = x or y)

func intersection*(a, b: BitVector): Option[BitVector] {.raises: [].} =
  ## Bits set in both; none when the sizes differ.
  combine(a, b, proc(x, y: uint64): uint64 = x and y)

func difference*(a, b: BitVector): Option[BitVector] {.raises: [].} =
  ## Bits set in `a` and not in `b`; none when the sizes differ.
  combine(a, b, proc(x, y: uint64): uint64 = x and not y)

func complement*(v: BitVector): BitVector {.raises: [].} =
  ## Every bit flipped within 0 ..< len (bits past the end stay 0).
  var words = newSeq[uint64](v.words.len)
  for i in 0 ..< words.len:
    words[i] = not v.words[i]
  let rest = v.nbits mod 64
  if rest > 0:
    words[^1] = words[^1] and ((1'u64 shl rest) - 1'u64)
  BitVector(words: words, nbits: v.nbits)

func invariantsHold*(v: BitVector): bool {.raises: [].} =
  ## Word count matches the size and no bit past the end is set.
  if v.nbits < 0 or v.words.len != wordCount(v.nbits): return false
  let rest = v.nbits mod 64
  rest == 0 or (v.words[^1] shr rest) == 0'u64
