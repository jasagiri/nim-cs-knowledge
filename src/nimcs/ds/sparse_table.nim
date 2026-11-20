## Sparse table: O(1) range queries for an idempotent operation, after an O(n log n) build.
##
## Level `k` stores, for every start `i`, the combination of the `2^k` elements from `i`. A query
## over `[l, r)` picks the largest `k` with `2^k <= r - l` and combines two level-`k` entries, one
## starting at `l` and one ending at `r`; the two windows overlap in the middle. The overlap
## counts the shared elements twice, which is harmless only when `op(x, x) == x` (idempotent):
## min, max, gcd, bitwise and/or. Sum, product and xor are not idempotent and give wrong answers
## here; use `fenwick_tree` or `segment_tree` for those. The table is built once and never
## updated (an update would rewrite O(n) entries per level); use `segment_tree` when the data
## changes. Only associativity and idempotence of `op` are used; the two windows are combined in
## index order, so non-commutative idempotent operations (such as "keep the left one") also work.

import std/[options, bitops]

type
  Op*[T] = proc(a, b: T): T {.noSideEffect, raises: [].}
  SparseTable*[T] = object
    op: Op[T]
    levels: seq[seq[T]]   ## levels[k][i] = op over items[i ..< i + 2^k]
    size: int

func fromSeq*[T](items: openArray[T]; op: Op[T]): SparseTable[T] {.raises: [].} =
  ## Builds all levels; O(n log n) time and space. `op` must be associative and idempotent for
  ## `query` to be correct (see `idempotentOn`).
  var levels = @[@items]
  var width = 1
  while width * 2 <= items.len:
    let prev = levels[^1]
    var next = newSeqOfCap[T](items.len - width * 2 + 1)
    for i in 0 .. items.len - width * 2:
      next.add op(prev[i], prev[i + width])
    levels.add next
    width *= 2
  SparseTable[T](op: op, levels: if items.len == 0: newSeq[seq[T]]() else: levels, size: items.len)

func len*[T](t: SparseTable[T]): int {.raises: [].} =
  t.size

func levelCount*[T](t: SparseTable[T]): int {.raises: [].} =
  ## Number of levels: floor(log2 n) + 1, or 0 for an empty table.
  t.levels.len

func query*[T](t: SparseTable[T]; l, r: int): Option[T] {.raises: [].} =
  ## `op` over elements l ..< r in O(1); none for an empty or out-of-range range (there is no
  ## identity element, so an empty range has no answer).
  if l < 0 or r > t.size or l >= r: return none(T)
  let k = fastLog2(r - l)
  some(t.op(t.levels[k][l], t.levels[k][r - (1 shl k)]))

func get*[T](t: SparseTable[T]; i: int): Option[T] {.raises: [].} =
  ## Element `i`; none when out of range.
  if i < 0 or i >= t.size: none(T) else: some(t.levels[0][i])

func idempotentOn*[T](op: Op[T]; samples: openArray[T]): bool {.raises: [].} =
  ## True when `op(x, x) == x` for every sample. A finite check can refute idempotence, not prove it.
  for x in samples:
    if op(x, x) != x: return false
  true
