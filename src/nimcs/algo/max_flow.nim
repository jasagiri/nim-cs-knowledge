## Maximum flow (Edmonds-Karp) and, as an application, maximum bipartite matching.
##
## Use it to ask how much can be sent from a source to a sink through capacity-limited arcs (pipes,
## links, assignments). The weight of each arc of a `Graph` is its capacity. Edmonds-Karp
## repeatedly sends flow along a shortest (fewest-arcs) path in the residual graph, which bounds
## the number of augmentations by V * E / 2 whatever the capacities are. The answer carries the
## flow, and a minimum cut found from the last residual graph, so the max-flow = min-cut law can
## be checked on every result. An undirected graph gives each direction of an edge its full
## capacity. Sums of capacities must fit in an `int` (an overflow is a Defect, not a value).

import std/algorithm
import nimcs/fp/result
import nimcs/algo/graph

type
  FlowError* = enum
    feVertexOutOfRange   ## source, sink or a matching pair names a vertex that does not exist
    feNegativeCapacity   ## an arc has a negative capacity
    feSameEndpoints      ## source and sink are the same vertex
    feNegativeCount      ## a bipartite side has a negative size

  FlowSolution* = object
    value*: int              ## the amount of flow from source to sink
    flows*: seq[Edge]        ## per ordered pair (source, target) the flow it carries (weight > 0), ascending
    sourceSide*: seq[int]    ## vertices still reachable from the source in the last residual graph, ascending
    cut*: seq[Edge]          ## the arcs from `sourceSide` to the other vertices: a minimum cut

func maxFlow*(g: Graph; source, sink: int): Result[FlowSolution, FlowError] {.raises: [].} =
  ## Maximum flow from `source` to `sink` (GRAPH-MAXFLOW-01), with the minimum cut that proves
  ## it is maximum (GRAPH-MAXFLOW-02). The flow respects every capacity and conserves flow at every
  ## other vertex (GRAPH-MAXFLOW-03). Fails on a bad vertex, equal endpoints or a negative
  ## capacity (GRAPH-MAXFLOW-04).
  if not g.inRange(source) or not g.inRange(sink):
    return err(FlowSolution, feVertexOutOfRange)
  if source == sink:
    return err(FlowSolution, feSameEndpoints)
  let n = g.vertexCount
  # Edge 2k is an original arc, edge 2k + 1 its reverse; `residual` is what can still be sent.
  var head: seq[int]            # head[e]: where edge e leads
  var residual: seq[int]
  var original: seq[int]
  var adj = newSeq[seq[int]](n)
  for u in 0 ..< n:
    for a in g.neighbors(u):
      if a.weight < 0:
        return err(FlowSolution, feNegativeCapacity)
      if a.target == u:
        continue                # a self-loop can carry no flow from source to sink
      adj[u].add head.len
      head.add a.target
      residual.add a.weight
      original.add a.weight
      adj[a.target].add head.len
      head.add u
      residual.add 0
      original.add 0
  var total = 0
  while true:
    var via = newSeq[int](n)    # edge used to reach each vertex, -1 = not reached
    for v in 0 ..< n:
      via[v] = -1
    var queue = @[source]
    var next = 0
    var reached = newSeq[bool](n)
    reached[source] = true
    while next < queue.len and not reached[sink]:
      let u = queue[next]
      inc next
      for e in adj[u]:
        if residual[e] > 0 and not reached[head[e]]:
          reached[head[e]] = true
          via[head[e]] = e
          queue.add head[e]
    if not reached[sink]:
      var side: seq[int]
      for v in 0 ..< n:
        if reached[v]:
          side.add v
      var cut: seq[Edge]
      var carried: seq[Edge]
      for u in 0 ..< n:
        for e in adj[u]:
          if e mod 2 == 0:
            let f = original[e] - residual[e]
            if f > 0:
              carried.add Edge(source: u, target: head[e], weight: f)
            if reached[u] and not reached[head[e]]:
              cut.add Edge(source: u, target: head[e], weight: original[e])
      carried = sorted(carried, proc(a, b: Edge): int =
        result = cmp(a.source, b.source)
        if result == 0:
          result = cmp(a.target, b.target))
      var merged: seq[Edge]
      for f in carried:
        if merged.len > 0 and merged[^1].source == f.source and merged[^1].target == f.target:
          merged[^1].weight += f.weight
        else:
          merged.add f
      return ok(FlowSolution(value: total, flows: merged, sourceSide: side, cut: cut), FlowError)
    var bottleneck = high(int)
    var v = sink
    while v != source:
      let e = via[v]
      bottleneck = min(bottleneck, residual[e])
      v = head[e xor 1]
    v = sink
    while v != source:
      let e = via[v]
      residual[e] -= bottleneck
      residual[e xor 1] += bottleneck
      v = head[e xor 1]
    total += bottleneck

func bipartiteMatching*(leftCount, rightCount: int;
    pairs: openArray[(int, int)]): Result[seq[(int, int)], FlowError] {.raises: [].} =
  ## A maximum set of (left, right) pairs, drawn from `pairs`, in which no left and no right
  ## vertex repeats (GRAPH-MATCHING-01, GRAPH-MATCHING-02). Left vertices are 0 ..< leftCount,
  ## right vertices 0 ..< rightCount. Ascending by left vertex. It is max flow in a network with
  ## a source before every left vertex and a sink after every right vertex, all capacities 1.
  ## Fails on a negative count or a pair outside the sides (GRAPH-MATCHING-03).
  if leftCount < 0 or rightCount < 0:
    return err(seq[(int, int)], feNegativeCount)
  let s = leftCount + rightCount
  let t = s + 1
  var arcs: seq[Edge]
  for l in 0 ..< leftCount:
    arcs.add edge(s, l, 1)
  for r in 0 ..< rightCount:
    arcs.add edge(leftCount + r, t, 1)
  for (l, r) in pairs:
    if l < 0 or l >= leftCount or r < 0 or r >= rightCount:
      return err(seq[(int, int)], feVertexOutOfRange)
    arcs.add edge(l, leftCount + r, 1)
  let g = buildGraph(t + 1, arcs, gkDirected)
  if not g.isOk:
    return err(seq[(int, int)], feVertexOutOfRange)
  let solved = maxFlow(g.value, s, t)
  if not solved.isOk:
    return err(seq[(int, int)], solved.error)
  var matching: seq[(int, int)]
  for f in solved.value.flows:
    if f.source < leftCount and f.target >= leftCount and f.target < s:
      matching.add (f.source, f.target - leftCount)
  ok(matching, FlowError)
