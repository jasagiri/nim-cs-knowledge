## An immutable graph value: vertices 0 ..< n and adjacency lists built from an edge list.
##
## Use it as the input of every graph algorithm in this package (`bfs`, `dfs`, `dijkstra`, ...).
## `buildGraph` is the only way to make one: it checks the edges and puts each neighbour list in
## ascending (target, weight) order, so the same set of edges gives equal graphs whatever order
## it arrived in, and every algorithm that visits neighbours in order is deterministic. An
## undirected edge is stored as two arcs (one for a self-loop). Parallel edges are kept.
## This module also holds the result types the algorithms share: `PathTree` and `SpanningForest`.

import std/[algorithm, options]
import nimcs/fp/result

type
  GraphKind* = enum
    gkDirected     ## an edge u -> v can be followed from u only
    gkUndirected   ## an edge u - v can be followed both ways

  GraphError* = enum
    geNegativeOrder      ## the vertex count is below zero
    geVertexOutOfRange   ## an endpoint (or a source) is not in 0 ..< n
    geNegativeWeight     ## the algorithm needs non-negative weights
    geNotUndirected      ## the algorithm is defined for undirected graphs only

  Edge* = object
    source*, target*, weight*: int

  Arc* = object
    ## One direction of an edge, as stored in a neighbour list.
    target*, weight*: int

  Graph* = object
    directed: bool
    adj: seq[seq[Arc]]

  PathTree* = object
    ## Shortest paths from one source: distance and predecessor of every vertex (none = unreached).
    source*: int
    dist*: seq[Option[int]]
    parent*: seq[Option[int]]

  SpanningForest* = object
    ## A minimum spanning tree of every connected component.
    edges*: seq[Edge]     ## in ascending (weight, source, target) order, source <= target
    totalWeight*: int
    components*: int

func `==`*(a, b: Edge): bool {.raises: [].} =
  a.source == b.source and a.target == b.target and a.weight == b.weight

func `==`*(a, b: Arc): bool {.raises: [].} =
  a.target == b.target and a.weight == b.weight

func `==`*(a, b: Graph): bool {.raises: [].} =
  a.directed == b.directed and a.adj == b.adj

func `==`*(a, b: PathTree): bool {.raises: [].} =
  a.source == b.source and a.dist == b.dist and a.parent == b.parent

func edge*(source, target: int; weight = 1): Edge {.raises: [].} =
  Edge(source: source, target: target, weight: weight)

func arcOrder(a, b: Arc): int =
  result = cmp(a.target, b.target)
  if result == 0:
    result = cmp(a.weight, b.weight)

func buildGraph*(order: int; edges: openArray[Edge]; kind: GraphKind): Result[Graph, GraphError] {.raises: [].} =
  ## A graph on vertices 0 ..< order. Fails when `order` is negative or an endpoint is outside
  ## that range (GRAPH-BUILD-02).
  if order < 0:
    return err(Graph, geNegativeOrder)
  var adj = newSeq[seq[Arc]](order)
  for e in edges:
    if e.source < 0 or e.source >= order or e.target < 0 or e.target >= order:
      return err(Graph, geVertexOutOfRange)
    adj[e.source].add Arc(target: e.target, weight: e.weight)
    if kind == gkUndirected and e.source != e.target:
      adj[e.target].add Arc(target: e.source, weight: e.weight)
  for v in 0 ..< order:
    adj[v] = sorted(adj[v], arcOrder)
  ok(Graph(directed: kind == gkDirected, adj: adj), GraphError)

func vertexCount*(g: Graph): int {.raises: [].} = g.adj.len

func isDirected*(g: Graph): bool {.raises: [].} = g.directed

func neighbors*(g: Graph; v: int): lent seq[Arc] {.raises: [].} =
  ## The arcs leaving `v`, ascending by (target, weight). `v` must be in 0 ..< vertexCount; an
  ## outside vertex is a caller bug and raises an `IndexDefect` (a Defect, not a failure value).
  g.adj[v]

func inRange*(g: Graph; v: int): bool {.raises: [].} = v >= 0 and v < g.adj.len

func arcCount*(g: Graph): int {.raises: [].} =
  for list in g.adj:
    result += list.len

func hasArc*(g: Graph; u, v: int): bool {.raises: [].} =
  ## Is there an arc u -> v? (Always symmetric for an undirected graph.)
  if not g.inRange(u) or not g.inRange(v):
    return false
  for a in g.adj[u]:
    if a.target == v:
      return true
  false

func edges*(g: Graph): seq[Edge] {.raises: [].} =
  ## Every edge once, in ascending (source, target, weight) order. For an undirected graph each
  ## edge is reported with source <= target (GRAPH-BUILD-03).
  for u in 0 ..< g.adj.len:
    for a in g.adj[u]:
      if g.directed or u <= a.target:
        result.add Edge(source: u, target: a.target, weight: a.weight)

func transpose*(g: Graph): Graph {.raises: [].} =
  ## Every arc reversed. An undirected graph is its own transpose (GRAPH-TRANSPOSE-01).
  if not g.directed:
    return g
  var adj = newSeq[seq[Arc]](g.adj.len)
  for u in 0 ..< g.adj.len:
    for a in g.adj[u]:
      adj[a.target].add Arc(target: u, weight: a.weight)
  for v in 0 ..< adj.len:
    adj[v] = sorted(adj[v], arcOrder)
  Graph(directed: true, adj: adj)

func distance*(t: PathTree; v: int): Option[int] {.raises: [].} =
  ## Length of a shortest path from the source to `v`; none when `v` is unreachable or not a vertex.
  if v < 0 or v >= t.dist.len: none(int) else: t.dist[v]

func pathTo*(t: PathTree; v: int): Option[seq[int]] {.raises: [].} =
  ## The vertices of a shortest path from the source to `v`, both ends included; none when
  ## `v` is unreachable (GRAPH-PATH-01).
  if v < 0 or v >= t.dist.len or t.dist[v].isNone:
    return none(seq[int])
  var path = @[v]
  var current = v
  while current != t.source:
    let p = t.parent[current]
    if p.isNone or path.len > t.dist.len:
      return none(seq[int])
    current = p.get
    path.add current
  path.reverse
  some(path)
