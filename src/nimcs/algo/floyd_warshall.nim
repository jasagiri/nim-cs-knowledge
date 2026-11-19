## Floyd-Warshall: shortest paths between every pair, by allowing one more intermediate vertex at a time.
##
## Use it when you need distances between all pairs on a small dense graph (V up to a few hundred):
## O(V^3) time, O(V^2) space. Negative weights are fine; a negative cycle is reported as an error.
## For one source on a sparse graph, `dijkstra` or `bellman_ford` is cheaper. Distances are `int`.

import std/options
import nimcs/fp/result
import nimcs/algo/graph

type
  AllPairs* = object
    n: int
    dist: seq[Option[int]]    ## row-major n x n
    firstHop: seq[int]        ## row-major n x n: the vertex after u on a shortest u -> v path

  FloydError* = object
    ## The graph has a negative cycle; `vertex` lies on one.
    vertex*: int

func distance*(ap: AllPairs; u, v: int): Option[int] {.raises: [].} =
  ## Length of a shortest path u -> v, none when v is unreachable from u or either is not a vertex.
  if u < 0 or u >= ap.n or v < 0 or v >= ap.n: none(int) else: ap.dist[u * ap.n + v]

func pathBetween*(ap: AllPairs; u, v: int): Option[seq[int]] {.raises: [].} =
  ## The vertices of a shortest path u -> v, both ends included; none when unreachable
  ## (GRAPH-FLOYD-03).
  if ap.distance(u, v).isNone:
    return none(seq[int])
  var path = @[u]
  var current = u
  while current != v:
    current = ap.firstHop[current * ap.n + v]
    path.add current
    if path.len > ap.n:
      return none(seq[int])
  some(path)

func floydWarshall*(g: Graph): Result[AllPairs, FloydError] {.raises: [].} =
  ## All-pairs shortest distances (GRAPH-FLOYD-01), or a negative cycle (GRAPH-FLOYD-02).
  let n = g.vertexCount
  var dist = newSeq[Option[int]](n * n)
  var hop = newSeq[int](n * n)
  for v in 0 ..< n:
    dist[v * n + v] = some(0)
    hop[v * n + v] = v
  for u in 0 ..< n:
    for a in g.neighbors(u):
      let at = u * n + a.target
      if dist[at].isNone or a.weight < dist[at].get:
        dist[at] = some(a.weight)
        hop[at] = a.target
  for k in 0 ..< n:
    for i in 0 ..< n:
      let ik = dist[i * n + k]
      if ik.isNone: continue
      for j in 0 ..< n:
        let kj = dist[k * n + j]
        if kj.isNone: continue
        let through = ik.get + kj.get
        if dist[i * n + j].isNone or through < dist[i * n + j].get:
          dist[i * n + j] = some(through)
          hop[i * n + j] = hop[i * n + k]
    # A negative diagonal entry is a negative cycle; stopping here keeps the values from
    # doubling pass after pass on a graph that has one.
    for v in 0 ..< n:
      if dist[v * n + v].get < 0:
        return err(AllPairs, FloydError(vertex: v))
  ok(AllPairs(n: n, dist: dist, firstHop: hop), FloydError)
