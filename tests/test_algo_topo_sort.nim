import std/[algorithm, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/scc
import nimcs/algo/topo_sort

type Raw = (int, seq[(int, (int, int))])   # vertex count, [(source, (target, weight))] before reduction mod count

proc raws(minW, maxW: int): Gen[Raw] {.raises: [ValueError].} =
  pair(intIn(1, 7), seqOf(pair(intIn(0, 99), pair(intIn(0, 99), intIn(minW, maxW))), 0, 14))

func edgesOf(raw: Raw): seq[Edge] {.raises: [].} =
  for (u, rest) in raw[1]:
    result.add edge(u mod raw[0], rest[0] mod raw[0], rest[1])

func build(raw: Raw; kind: GraphKind): Graph {.raises: [].} =
  ## The generated edges are always in range, so building cannot fail.
  buildGraph(raw[0], edgesOf(raw), kind).value

func dagOf(raw: Raw): Graph {.raises: [].} =
  ## Only edges that go from a smaller to a larger vertex: acyclic by construction.
  var es: seq[Edge]
  for e in edgesOf(raw):
    if e.source < e.target: es.add e
  buildGraph(raw[0], es, gkDirected).value


func respects(g: Graph; order: seq[int]): bool {.raises: [].} =
  ## Is `order` a permutation of the vertices with every arc pointing forward?
  var all: seq[int]
  for v in 0 ..< g.vertexCount: all.add v
  if order.sorted != all: return false
  var at = newSeq[int](g.vertexCount)
  for i, v in order: at[v] = i
  for u in 0 ..< g.vertexCount:
    for a in g.neighbors(u):
      if at[a.target] <= at[u]: return false
  true

func isCycle(g: Graph; cycle: seq[int]): bool {.raises: [].} =
  if cycle.len == 0: return false
  for i in 0 ..< cycle.len:
    if not g.hasArc(cycle[i], cycle[(i + 1) mod cycle.len]): return false
  true

func smallestFirst(g: Graph): seq[int] {.raises: [].} =
  ## Oracle for an acyclic graph: repeatedly place the smallest vertex whose predecessors are all placed.
  var placed = newSeq[bool](g.vertexCount)
  for _ in 0 ..< g.vertexCount:
    for v in 0 ..< g.vertexCount:
      if placed[v]: continue
      var free = true
      for u in 0 ..< g.vertexCount:
        if not placed[u] and g.hasArc(u, v): free = false
      if free:
        placed[v] = true
        result.add v
        break

# SPEC: GRAPH-TOPO-01
test "GRAPH-TOPO-01 Given an acyclic graph, when sorted topologically, then every vertex appears once and every arc points forward":
  let outcome = check(raws(1, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = dagOf(raw)
    let r = topoSort(g)
    r.isOk and respects(g, r.value))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-TOPO-02
test "GRAPH-TOPO-02 Given any directed graph, when sorted, then it either yields a valid order or names a real cycle":
  let outcome = check(raws(1, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw, gkDirected)
    let r = topoSort(g)
    if r.isOk: respects(g, r.value) else: isCycle(g, r.error.vertices))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-TOPO-02
test "GRAPH-TOPO-02 Given a self-loop or a two-vertex loop, when sorted, then the cycle is reported":
  let selfLoop = buildGraph(3, @[edge(0, 1), edge(1, 1)], gkDirected).value
  check topoSort(selfLoop).error.vertices == @[1]
  let loop = buildGraph(3, @[edge(0, 1), edge(1, 2), edge(2, 1)], gkDirected).value
  check topoSort(loop).error.vertices == @[1, 2]
  let undirected = buildGraph(2, @[edge(0, 1)], gkUndirected).value
  check topoSort(undirected).isErr

# SPEC: GRAPH-TOPO-03
test "GRAPH-TOPO-03 Given an acyclic graph, when sorted, then the order is the lexicographically smallest valid one":
  let outcome = check(raws(1, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = dagOf(raw)
    topoSort(g) == ok(smallestFirst(g), TopoCycle))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-TOPO-04
test "GRAPH-TOPO-04 Given any directed graph, when sorted, then it fails exactly when a component has several vertices or a vertex loops":
  let outcome = check(raws(1, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw, gkDirected)
    var cyclic = false
    for comp in stronglyConnectedComponents(g):
      if comp.len > 1 or g.hasArc(comp[0], comp[0]): cyclic = true
    topoSort(g).isErr == cyclic)
  checkpoint describe(outcome)
  check outcome.passed
