## Lowest common ancestor by binary lifting.
##
## A rooted tree is given as a parent array (the root's parent is -1). Preprocessing stores, for
## every vertex v and every k, the 2^k-th ancestor `up[k][v]`, in O(n log n) space; any ancestor
## k steps up is then reached by the set bits of k, and the LCA of u and v is found by lifting the
## deeper vertex to the other's depth and then lifting both together while their ancestors differ.
## Each query costs O(log n). Use it when a tree is fixed and many queries follow (distances,
## path queries); for a single query walking up the parent array is simpler, and an Euler tour
## with a sparse table gives O(1) queries at the same preprocessing cost.
##
## The structure is an immutable value; a query never changes it. A vertex outside the tree is
## answered with none rather than an error, since asking about it is an ordinary question.

import std/options
import nimcs/fp/result

type
  LcaError* = enum
    leEmpty             ## a tree needs at least one vertex
    leParentOutOfRange  ## a parent is neither -1 nor a vertex
    leRootCount         ## the number of vertices whose parent is -1 is not exactly one
    leNotConnected      ## some vertex cannot reach the root (a cycle among parents)

  LcaTree* = object
    depths: seq[int]
    up: seq[seq[int]]      ## up[k][v] = the 2^k-th ancestor of v, or -1 beyond the root

func buildLca*(parent: openArray[int]): Result[LcaTree, LcaError] {.raises: [].} =
  ## Prepares `parent` (parent[v] is the parent of v, -1 for the one root) for queries. Fails
  ## when it is empty, names a parent out of range, has no root or several, or contains a cycle
  ## (LCA-BUILD-01).
  let n = parent.len
  if n == 0:
    return err(LcaTree, leEmpty)
  var root = -1
  var rootCount = 0
  var children = newSeq[seq[int]](n)
  for v, p in parent:
    if p < -1 or p >= n:
      return err(LcaTree, leParentOutOfRange)
    if p == -1:
      root = v
      inc rootCount
    else:
      children[p].add v
  if rootCount != 1:
    return err(LcaTree, leRootCount)
  # Breadth first from the root: parents come before children, and every vertex is reached
  # exactly once unless the parent links contain a cycle.
  var depths = newSeq[int](n)
  var order = @[root]
  var head = 0
  while head < order.len:
    let v = order[head]
    inc head
    for c in children[v]:
      depths[c] = depths[v] + 1
      order.add c
  if order.len != n:
    return err(LcaTree, leNotConnected)
  var levels = 1
  while (1 shl levels) < n:
    inc levels
  var up = newSeq[seq[int]](levels)
  up[0] = @parent
  for k in 1 ..< levels:
    up[k] = newSeq[int](n)
    for v in 0 ..< n:
      let mid = up[k - 1][v]
      up[k][v] = if mid < 0: -1 else: up[k - 1][mid]
  ok(LcaTree(depths: depths, up: up), LcaError)

func size*(t: LcaTree): int {.raises: [].} = t.depths.len

func contains*(t: LcaTree; v: int): bool {.raises: [].} = v >= 0 and v < t.depths.len

func depth*(t: LcaTree; v: int): Option[int] {.raises: [].} =
  ## Number of edges from the root to `v`; none when `v` is not a vertex (LCA-DEPTH-01).
  if v in t: some(t.depths[v]) else: none(int)

func kthAncestor*(t: LcaTree; v, k: int): Option[int] {.raises: [].} =
  ## The vertex `k` steps above `v` (k = 0 is `v`); none when `v` is not a vertex, `k` is negative,
  ## or `k` goes past the root (LCA-ANCESTOR-01).
  if v notin t or k < 0 or k > t.depths[v]:
    return none(int)
  var current = v
  for bit in 0 ..< t.up.len:
    if ((k shr bit) and 1) == 1:
      current = t.up[bit][current]
  some(current)

func lca*(t: LcaTree; u, v: int): Option[int] {.raises: [].} =
  ## The deepest vertex that is an ancestor of both `u` and `v` (a vertex is its own ancestor);
  ## none when either is not a vertex (LCA-QUERY-01, LCA-QUERY-02).
  if u notin t or v notin t:
    return none(int)
  var a = u
  var b = v
  if t.depths[a] < t.depths[b]:
    swap(a, b)
  a = t.kthAncestor(a, t.depths[a] - t.depths[b]).get
  if a == b:
    return some(a)
  for bit in countdown(t.up.len - 1, 0):
    if t.up[bit][a] != t.up[bit][b]:
      a = t.up[bit][a]
      b = t.up[bit][b]
  some(t.up[0][a])

func distance*(t: LcaTree; u, v: int): Option[int] {.raises: [].} =
  ## Number of edges on the path between `u` and `v`; none when either is not a vertex
  ## (LCA-DISTANCE-01).
  let meet = t.lca(u, v)
  if meet.isNone:
    return none(int)
  some(t.depths[u] + t.depths[v] - 2 * t.depths[meet.get])
