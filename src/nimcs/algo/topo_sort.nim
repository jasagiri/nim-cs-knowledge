## Topological sort (Kahn's algorithm): repeatedly take a vertex with no remaining incoming arc.
##
## Use it to order tasks, build steps or modules so that every dependency comes before what needs
## it. It runs in O((V + E) log V) because the ready vertices sit in a small priority queue; that
## makes the answer the lexicographically smallest valid order, which is deterministic. A cycle has
## no valid order: the error carries one cycle, so the caller can report it.

import std/heapqueue
import nimcs/fp/result
import nimcs/algo/graph

type TopoCycle* = object
  ## A directed cycle v0 -> v1 -> ... -> vk -> v0, listed once around (no repeated first vertex), starting at its smallest vertex.
  vertices*: seq[int]

func findCycle(g: Graph; removed: seq[bool]): seq[int] {.raises: [].} =
  ## Every vertex still present has an incoming arc from another present vertex; following those
  ## arcs backwards from any vertex must therefore close a loop.
  let n = g.vertexCount
  var pred = newSeq[int](n)
  for v in 0 ..< n:
    pred[v] = -1
  var start = -1
  for u in 0 ..< n:
    if removed[u]: continue
    if start < 0: start = u
    for a in g.neighbors(u):
      if not removed[a.target] and pred[a.target] < 0:
        pred[a.target] = u
  var seenAt = newSeq[int](n)
  for v in 0 ..< n:
    seenAt[v] = -1
  var walk: seq[int]
  var current = start
  while seenAt[current] < 0:
    seenAt[current] = walk.len
    walk.add current
    current = pred[current]
  for i in countdown(walk.len - 1, seenAt[current]):
    result.add walk[i]
  var at = 0
  for i, v in result:
    if v < result[at]: at = i
  # Start at the smallest vertex, so the report does not depend on where the walk began.
  result = result[at .. ^1] & result[0 ..< at]

func topoSort*(g: Graph): Result[seq[int], TopoCycle] {.raises: [].} =
  ## All vertices, each before every vertex it has an arc to (GRAPH-TOPO-01), the smallest
  ## vertex first whenever there is a choice (GRAPH-TOPO-03). If the graph has a cycle, the error
  ## holds a real cycle of the graph (GRAPH-TOPO-02). An undirected edge counts as a cycle of two.
  let n = g.vertexCount
  var indegree = newSeq[int](n)
  for u in 0 ..< n:
    for a in g.neighbors(u):
      inc indegree[a.target]
  var ready = initHeapQueue[int]()
  for v in 0 ..< n:
    if indegree[v] == 0:
      ready.push v
  var order: seq[int]
  var removed = newSeq[bool](n)
  while ready.len > 0:
    let u = ready.pop
    order.add u
    removed[u] = true
    for a in g.neighbors(u):
      dec indegree[a.target]
      if indegree[a.target] == 0:
        ready.push a.target
  if order.len == n:
    ok(order, TopoCycle)
  else:
    err(seq[int], TopoCycle(vertices: findCycle(g, removed)))
