## Prim's algorithm: grow one tree from a start vertex, always adding the cheapest edge that leaves it.
##
## Use it for the same job as `kruskal` (minimum spanning tree of an undirected weighted graph),
## typically when the graph is dense or given as adjacency lists. A binary heap of candidate edges
## gives O(E log V). When the graph is disconnected a new tree is started from the smallest
## unvisited vertex, so the result is a spanning forest. A directed graph is refused.

import std/[algorithm, heapqueue]
import nimcs/fp/result
import nimcs/algo/graph

func byWeight(a, b: Edge): int =
  result = cmp(a.weight, b.weight)
  if result == 0:
    result = cmp(a.source, b.source)
  if result == 0:
    result = cmp(a.target, b.target)

func prim*(g: Graph): Result[SpanningForest, GraphError] {.raises: [].} =
  ## A minimum spanning forest (GRAPH-PRIM-01). Fails with `geNotUndirected` for a directed graph.
  if g.isDirected:
    return err(SpanningForest, geNotUndirected)
  let n = g.vertexCount
  var inTree = newSeq[bool](n)
  var forest = SpanningForest()
  for start in 0 ..< n:
    if inTree[start]: continue
    inc forest.components
    inTree[start] = true
    var candidates = initHeapQueue[(int, int, int)]()    # (weight, from, to)
    for a in g.neighbors(start):
      candidates.push (a.weight, start, a.target)
    while candidates.len > 0:
      let (w, u, v) = candidates.pop
      if inTree[v]: continue
      inTree[v] = true
      forest.edges.add edge(min(u, v), max(u, v), w)
      forest.totalWeight += w
      for a in g.neighbors(v):
        if not inTree[a.target]:
          candidates.push (a.weight, v, a.target)
  forest.edges = sorted(forest.edges, byWeight)
  ok(forest, GraphError)
