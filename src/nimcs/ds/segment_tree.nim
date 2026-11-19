## Immutable segment tree over a monoid: range queries and point updates in O(log n).
##
## A monoid is an associative `combine` with an `identity`. The tree stores, in every node, the
## combination of the elements below it, so a query over a half-open range [l, r) combines at most
## about 2 log2(n) stored values. A point update copies one root-to-leaf path and shares the rest,
## so the old tree stays valid. Because only associativity is required (not commutativity), the
## order of elements is respected: string concatenation works. Use it for repeated range sums,
## minima, gcds or any associative summary over an array with updates; use a prefix-sum array when
## the data never changes.

import std/options

type
  Monoid*[T] = object
    identity*: T
    combine*: proc(a, b: T): T {.noSideEffect, raises: [].}
  Node[T] = ref object
    value: T
    left, right: Node[T]     ## nil in leaves
  SegTree*[T] = object
    monoid: Monoid[T]
    root: Node[T]
    size: int

func initMonoid*[T](identity: T; combine: proc(a, b: T): T {.noSideEffect, raises: [].}): Monoid[T] {.raises: [].} =
  Monoid[T](identity: identity, combine: combine)

func buildNode[T](m: Monoid[T]; items: openArray[T]; lo, hi: int): Node[T] =
  ## Node for items[lo ..< hi], hi > lo.
  if hi - lo == 1: Node[T](value: items[lo])
  else:
    let mid = (lo + hi) div 2
    let l = buildNode(m, items, lo, mid)
    let r = buildNode(m, items, mid, hi)
    Node[T](value: m.combine(l.value, r.value), left: l, right: r)

func fromSeq*[T](m: Monoid[T]; items: openArray[T]): SegTree[T] {.raises: [].} =
  if items.len == 0: SegTree[T](monoid: m, size: 0)
  else: SegTree[T](monoid: m, root: buildNode(m, items, 0, items.len), size: items.len)

func len*[T](t: SegTree[T]): int {.raises: [].} =
  t.size

func queryNode[T](m: Monoid[T]; n: Node[T]; lo, hi, l, r: int): T =
  ## Combination of the elements of [lo, hi) that fall inside [l, r).
  if r <= lo or hi <= l: m.identity
  elif l <= lo and hi <= r: n.value
  else:
    let mid = (lo + hi) div 2
    m.combine(queryNode(m, n.left, lo, mid, l, r), queryNode(m, n.right, mid, hi, l, r))

func query*[T](t: SegTree[T]; l, r: int): Option[T] {.raises: [].} =
  ## Combination of elements l, l+1, ..., r-1 in order. An empty range gives the identity; a range
  ## outside 0 <= l <= r <= len gives none.
  if l < 0 or r > t.size or l > r: none(T)
  elif l == r: some(t.monoid.identity)
  else: some(queryNode(t.monoid, t.root, 0, t.size, l, r))

func updateNode[T](m: Monoid[T]; n: Node[T]; lo, hi, i: int; x: T): Node[T] =
  if hi - lo == 1: Node[T](value: x)
  else:
    let mid = (lo + hi) div 2
    let l = if i < mid: updateNode(m, n.left, lo, mid, i, x) else: n.left
    let r = if i < mid: n.right else: updateNode(m, n.right, mid, hi, i, x)
    Node[T](value: m.combine(l.value, r.value), left: l, right: r)

func updated*[T](t: SegTree[T]; i: int; x: T): Option[SegTree[T]] {.raises: [].} =
  ## A tree with element `i` replaced by `x`; none when out of range.
  if i < 0 or i >= t.size: none(SegTree[T])
  else: some(SegTree[T](monoid: t.monoid, root: updateNode(t.monoid, t.root, 0, t.size, i, x), size: t.size))

func get*[T](t: SegTree[T]; i: int): Option[T] {.raises: [].} =
  if i < 0 or i >= t.size: none(T)
  else: t.query(i, i + 1)

func total*[T](t: SegTree[T]): T {.raises: [].} =
  ## Combination of all elements (the identity when empty).
  if t.size == 0: t.monoid.identity else: t.root.value
