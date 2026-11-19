## Persistent union-find (disjoint sets) built on a persistent map.
##
## The classic imperative version keeps parents in an array and compresses paths while it finds,
## giving near-constant amortized time but destroying the old state. Here the parent and rank
## tables are `RbMap`s, so `union` returns a new structure and every earlier version stays
## usable (backtracking, undo, speculative merges). Union by rank alone bounds a root path by
## log2(n), so `find` is O(log n * log n) with the map lookups; `findCompress` also returns the
## compressed structure, which you must keep to benefit. Use it when you need old versions;
## use an array with path compression when only the latest state matters and speed counts.

import std/options
import nimcs/ds/rb_tree

type
  UnionFind* = object
    parent: RbMap[int, int]
    rank: RbMap[int, int]
    sets: int

func emptyUnionFind*(): UnionFind {.raises: [].} =
  UnionFind()

func components*(u: UnionFind): int {.raises: [].} =
  ## Number of disjoint sets among the elements seen so far.
  u.sets

func len*(u: UnionFind): int {.raises: [].} =
  ## Number of elements seen so far.
  u.parent.len

func contains*(u: UnionFind; x: int): bool {.raises: [].} =
  u.parent.contains(x)

func add*(u: UnionFind; x: int): UnionFind {.raises: [].} =
  ## Registers `x` as a singleton set; no change when it is already known.
  if u.contains(x): u
  else: UnionFind(parent: u.parent.put(x, x), rank: u.rank.put(x, 0), sets: u.sets + 1)

func parentOf(u: UnionFind; x: int): int =
  let p = u.parent.get(x)
  if p.isSome: p.get else: x

func find*(u: UnionFind; x: int): int {.raises: [].} =
  ## The representative of the set of `x`; an unknown element is its own representative.
  var cur = x
  while true:
    let p = u.parentOf(cur)
    if p == cur: return cur
    cur = p

func findCompress*(u: UnionFind; x: int): (int, UnionFind) {.raises: [].} =
  ## Like `find`, and also returns the structure with every node on the path pointing at the root.
  let root = u.find(x)
  var parent = u.parent
  var cur = x
  while cur != root and parent.get(cur).isSome:
    let p = parent.get(cur).get
    if p != root: parent = parent.put(cur, root)
    cur = p
  (root, UnionFind(parent: parent, rank: u.rank, sets: u.sets))

func rankOf(u: UnionFind; x: int): int =
  let r = u.rank.get(x)
  if r.isSome: r.get else: 0

func union*(u: UnionFind; a, b: int): UnionFind {.raises: [].} =
  ## Merges the sets of `a` and `b` (adding unknown elements first); idempotent.
  let base = u.add(a).add(b)
  let ra = base.find(a)
  let rb = base.find(b)
  if ra == rb: return base
  let rka = base.rankOf(ra)
  let rkb = base.rankOf(rb)
  if rka < rkb:
    UnionFind(parent: base.parent.put(ra, rb), rank: base.rank, sets: base.sets - 1)
  elif rkb < rka:
    UnionFind(parent: base.parent.put(rb, ra), rank: base.rank, sets: base.sets - 1)
  else:
    UnionFind(parent: base.parent.put(rb, ra), rank: base.rank.put(ra, rka + 1), sets: base.sets - 1)

func same*(u: UnionFind; a, b: int): bool {.raises: [].} =
  u.find(a) == u.find(b)

func pathLength*(u: UnionFind; x: int): int {.raises: [].} =
  ## Number of parent links from `x` to its representative.
  var cur = x
  while true:
    let p = u.parentOf(cur)
    if p == cur: return result
    cur = p
    inc result
