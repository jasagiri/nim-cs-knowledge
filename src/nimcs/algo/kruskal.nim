## Kruskal's algorithm: take the cheapest edges first, skipping any that would close a cycle.
##
## Use it to connect all vertices of an undirected weighted graph at least total cost (cabling,
## clustering). Sorting the edges dominates: O(E log E); a union-find forest (union by size and
## path halving: inverse-Ackermann amortized) tells in near-constant time whether two vertices are already joined. On a disconnected graph the result is a spanning
## forest, one tree per component. A directed graph is refused. `prim` gives the same total weight.

import std/algorithm
import nimcs/fp/result
import nimcs/algo/graph

func root(parent: var seq[int]; x: int): int {.raises: [].} =
  ## Representative of x's set; halves the path as it climbs.
  var current = x
  while parent[current] != current:
    parent[current] = parent[parent[current]]
    current = parent[current]
  current

func byWeight(a, b: Edge): int =
  result = cmp(a.weight, b.weight)
  if result == 0:
    result = cmp(a.source, b.source)
  if result == 0:
    result = cmp(a.target, b.target)

func kruskal*(g: Graph): Result[SpanningForest, GraphError] {.raises: [].} =
  ## A minimum spanning forest (GRAPH-KRUSKAL-01). Fails with `geNotUndirected` for a directed graph.
  if g.isDirected:
    return err(SpanningForest, geNotUndirected)
  let n = g.vertexCount
  var parent = newSeq[int](n)
  var size = newSeq[int](n)
  for v in 0 ..< n:
    parent[v] = v
    size[v] = 1
  var forest = SpanningForest(components: n)
  for e in sorted(g.edges, byWeight):
    let a = root(parent, e.source)
    let b = root(parent, e.target)
    if a != b:
      let (big, small) = if size[a] >= size[b]: (a, b) else: (b, a)
      parent[small] = big          # the smaller tree hangs under the larger: depth stays O(log n)
      size[big] += size[small]
      forest.edges.add e
      forest.totalWeight += e.weight
      dec forest.components
  ok(forest, GraphError)
