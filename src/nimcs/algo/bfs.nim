## Breadth-first search: visit vertices in rings of increasing edge count from a source.
##
## Use it for shortest paths when every edge counts the same (fewest hops), for reachability, and
## as the skeleton of other searches. It runs in O(V + E). Weights in the graph are ignored; use
## `dijkstra` when they matter. The result is a `PathTree` whose distances are numbers of edges.

import std/options
import nimcs/fp/result
import nimcs/algo/graph

func bfs*(g: Graph; source: int): Result[PathTree, GraphError] {.raises: [].} =
  ## Fewest-edge distances and predecessors from `source`. Fails when `source` is not a vertex.
  ## Neighbours are taken in the graph's order, so the tree is deterministic (GRAPH-BFS-01).
  if not g.inRange(source):
    return err(PathTree, geVertexOutOfRange)
  let n = g.vertexCount
  var dist = newSeq[Option[int]](n)
  var parent = newSeq[Option[int]](n)
  var queue = @[source]
  var head = 0
  dist[source] = some(0)
  while head < queue.len:
    let u = queue[head]
    inc head
    let du = dist[u].get
    for a in g.neighbors(u):
      if dist[a.target].isNone:
        dist[a.target] = some(du + 1)
        parent[a.target] = some(u)
        queue.add a.target
  ok(PathTree(source: source, dist: dist, parent: parent), GraphError)
