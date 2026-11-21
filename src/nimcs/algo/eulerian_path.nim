## Eulerian trails by Hierholzer's algorithm: walk every edge of a graph exactly once.
##
## A trail that uses every edge once exists exactly when the edges form one connected piece and the
## degrees allow it. Undirected: zero or two vertices of odd degree (a self-loop adds 2). Directed:
## every vertex has out-degree equal to in-degree, except possibly one start vertex with one more
## out than in and one end vertex with one more in than out. Hierholzer's algorithm follows unused
## edges until it is stuck, which can only happen back at the start of a closed loop, and splices
## the loops it finds on the way back: an explicit stack of vertices, a pointer into each
## adjacency list, and the vertices written out in the order they are abandoned, reversed. Use it
## for route inspection, stroke-order puzzles and de Bruijn sequences.
##
## A trail is the list of vertices visited, so it has one more entry than the graph has edges; a
## graph with no edge has the empty trail. The answer is deterministic: the start is the
## unbalanced or odd-degree vertex when there is one, else the smallest vertex that has an edge,
## and edges are taken in the graph's neighbour order.

import std/options
import nimcs/algo/graph

type EulerPlan = object
  adjacency: seq[seq[(int, int)]]   ## per vertex: (neighbour, edge id), in neighbour order
  start: int
  edgeCount: int

func plan(g: Graph): Option[EulerPlan] {.raises: [].} =
  ## The adjacency with edge ids and a start vertex, or none when the degrees forbid a trail.
  let es = g.edges
  let n = g.vertexCount
  var adjacency = newSeq[seq[(int, int)]](n)
  var outDeg = newSeq[int](n)
  var inDeg = newSeq[int](n)
  for id, e in es:
    adjacency[e.source].add (e.target, id)
    inc outDeg[e.source]
    inc inDeg[e.target]
    if not g.isDirected:
      if e.source != e.target:
        adjacency[e.target].add (e.source, id)
      # An undirected edge is traversable both ways, so it counts at both ends.
      inc outDeg[e.target]
      inc inDeg[e.source]
  var first = -1        # smallest vertex that has an edge
  var startUp = -1      # vertex with one more out than in (directed) / smallest odd vertex (undirected)
  var endUp = -1
  var odd = 0
  for v in 0 ..< n:
    if outDeg[v] + inDeg[v] > 0 and first < 0:
      first = v
    if g.isDirected:
      let d = outDeg[v] - inDeg[v]
      if d == 1 and startUp < 0:
        startUp = v
      elif d == -1 and endUp < 0:
        endUp = v
      elif d != 0:
        return none(EulerPlan)
    elif outDeg[v] mod 2 == 1:
      inc odd
      if startUp < 0:
        startUp = v
  if g.isDirected and (startUp < 0) != (endUp < 0):
    return none(EulerPlan)
  if not g.isDirected and odd != 0 and odd != 2:
    return none(EulerPlan)
  some(EulerPlan(adjacency: adjacency, start: (if startUp >= 0: startUp else: first),
                 edgeCount: es.len))

func eulerianPath*(g: Graph): Option[seq[int]] {.raises: [].} =
  ## A trail using every edge exactly once, as the vertices visited; none when the degrees forbid
  ## one or the edges are not connected (GRAPH-EULER-01, GRAPH-EULER-02). A graph without edges
  ## has the empty trail (GRAPH-EULER-05).
  let p = plan(g)
  if p.isNone:
    return none(seq[int])
  let ctx = p.get
  if ctx.edgeCount == 0:
    return some(newSeq[int]())
  var used = newSeq[bool](ctx.edgeCount)
  var pointer = newSeq[int](g.vertexCount)
  var stack = @[ctx.start]
  var reverseTrail: seq[int]
  while stack.len > 0:
    let v = stack[^1]
    while pointer[v] < ctx.adjacency[v].len and used[ctx.adjacency[v][pointer[v]][1]]:
      inc pointer[v]
    if pointer[v] < ctx.adjacency[v].len:
      let (to, id) = ctx.adjacency[v][pointer[v]]
      used[id] = true
      stack.add to
    else:
      reverseTrail.add v
      stack.delete(stack.high)
  if reverseTrail.len != ctx.edgeCount + 1:
    return none(seq[int])        # some edges lie in a different component
  var trail = newSeq[int](reverseTrail.len)
  for i, v in reverseTrail:
    trail[reverseTrail.len - 1 - i] = v
  some(trail)

func eulerianCircuit*(g: Graph): Option[seq[int]] {.raises: [].} =
  ## A closed trail using every edge exactly once (first and last vertex equal), or none when the
  ## graph has no Eulerian trail or none that returns to its start (GRAPH-EULER-03).
  let trail = eulerianPath(g)
  if trail.isNone or (trail.get.len > 0 and trail.get[0] != trail.get[^1]):
    return none(seq[int])
  trail
