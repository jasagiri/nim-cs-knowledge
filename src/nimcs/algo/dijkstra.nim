## Dijkstra's algorithm: settle vertices in order of distance, always from the closest unsettled one.
##
## Use it for shortest paths on graphs whose weights are all non-negative (travel time, cost).
## A binary heap with lazy deletion gives O((V + E) log V). With a negative weight the greedy
## argument fails, so this refuses the graph; use `bellman_ford` instead. Distances are `int`
## sums of weights: the caller keeps them small enough not to overflow (an overflow is a Defect).

import std/[heapqueue, options]
import nimcs/fp/result
import nimcs/algo/graph

func dijkstra*(g: Graph; source: int): Result[PathTree, GraphError] {.raises: [].} =
  ## Shortest distances and predecessors from `source` (GRAPH-DIJKSTRA-01). Fails with
  ## `geVertexOutOfRange` for a bad source and `geNegativeWeight` when any arc is negative
  ## (GRAPH-DIJKSTRA-02). Unreachable vertices have distance none.
  if not g.inRange(source):
    return err(PathTree, geVertexOutOfRange)
  let n = g.vertexCount
  for u in 0 ..< n:
    for a in g.neighbors(u):
      if a.weight < 0:
        return err(PathTree, geNegativeWeight)
  var dist = newSeq[Option[int]](n)
  var parent = newSeq[Option[int]](n)
  var settled = newSeq[bool](n)
  var frontier = initHeapQueue[(int, int)]()    # (distance, vertex): ties go to the smaller vertex
  dist[source] = some(0)
  frontier.push (0, source)
  while frontier.len > 0:
    let (d, u) = frontier.pop
    if settled[u]: continue
    settled[u] = true
    for a in g.neighbors(u):
      let candidate = d + a.weight
      if dist[a.target].isNone or candidate < dist[a.target].get:
        dist[a.target] = some(candidate)
        parent[a.target] = some(u)
        frontier.push (candidate, a.target)
  ok(PathTree(source: source, dist: dist, parent: parent), GraphError)
