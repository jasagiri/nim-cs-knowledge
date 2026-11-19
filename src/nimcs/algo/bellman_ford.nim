## Bellman-Ford: relax every arc, V - 1 times; a further improvement proves a negative cycle.
##
## Use it for shortest paths when weights may be negative, or to detect a negative cycle (an
## arbitrage loop, an impossible constraint set). It costs O(V * E), slower than `dijkstra`, which
## is the better choice when no weight is negative. A negative cycle reachable from the source
## makes "shortest" meaningless, so the error value carries such a cycle instead of a bogus tree.
## An undirected edge of negative weight is a negative cycle of two arcs. Distances are `int`.

import std/[algorithm, options]
import nimcs/fp/result
import nimcs/algo/graph

type
  BellmanFordFailure* = enum
    bfBadSource       ## the source is not a vertex
    bfNegativeCycle   ## a negative cycle is reachable from the source

  BellmanFordError* = object
    case kind*: BellmanFordFailure
    of bfBadSource: discard
    of bfNegativeCycle:
      cycle*: seq[int]    ## v0 -> v1 -> ... -> vk -> v0, listed once around, starting at its smallest vertex

func cycleThrough(parent: seq[int]; changed: int): seq[int] {.raises: [].} =
  ## `changed` improved on the last pass, so following predecessors from it enters a cycle
  ## within n steps; then the cycle is read off.
  var inside = changed
  for _ in 0 ..< parent.len:
    inside = parent[inside]
  var backwards = @[inside]
  var current = parent[inside]
  while current != inside:
    backwards.add current
    current = parent[current]
  backwards.reverse
  var at = 0
  for i, v in backwards:
    if v < backwards[at]: at = i
  # Start at the smallest vertex, so the report does not depend on where the walk landed.
  backwards[at .. ^1] & backwards[0 ..< at]

func bellmanFord*(g: Graph; source: int): Result[PathTree, BellmanFordError] {.raises: [].} =
  ## Shortest distances from `source` (GRAPH-BELLMAN-01), or a negative cycle reachable from it
  ## (GRAPH-BELLMAN-02).
  if not g.inRange(source):
    return err(PathTree, BellmanFordError(kind: bfBadSource))
  let n = g.vertexCount
  var dist = newSeq[int](n)
  var reached = newSeq[bool](n)
  var parent = newSeq[int](n)
  for v in 0 ..< n:
    parent[v] = -1
  reached[source] = true
  for pass in 1 .. n:
    var changed = -1
    for u in 0 ..< n:
      if not reached[u]: continue
      for a in g.neighbors(u):
        let candidate = dist[u] + a.weight
        if not reached[a.target] or candidate < dist[a.target]:
          reached[a.target] = true
          dist[a.target] = candidate
          parent[a.target] = u
          changed = a.target
    if changed < 0:
      break
    if pass == n:
      return err(PathTree, BellmanFordError(kind: bfNegativeCycle, cycle: cycleThrough(parent, changed)))
  var distances = newSeq[Option[int]](n)
  var parents = newSeq[Option[int]](n)
  for v in 0 ..< n:
    if reached[v]:
      distances[v] = some(dist[v])
    if parent[v] >= 0 and v != source:
      parents[v] = some(parent[v])
  ok(PathTree(source: source, dist: distances, parent: parents), BellmanFordError)
