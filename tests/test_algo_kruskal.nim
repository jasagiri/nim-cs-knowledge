import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/scc
import nimcs/algo/kruskal
import nimcs/algo/prim

type Raw = (int, seq[(int, (int, int))])   # vertex count, [(source, (target, weight))] before reduction mod count

proc raws(minW, maxW: int): Gen[Raw] {.raises: [ValueError].} =
  pair(intIn(1, 7), seqOf(pair(intIn(0, 99), pair(intIn(0, 99), intIn(minW, maxW))), 0, 14))

func edgesOf(raw: Raw): seq[Edge] {.raises: [].} =
  for (u, rest) in raw[1]:
    result.add edge(u mod raw[0], rest[0] mod raw[0], rest[1])

func build(raw: Raw; kind: GraphKind): Graph {.raises: [].} =
  ## The generated edges are always in range, so building cannot fail.
  buildGraph(raw[0], edgesOf(raw), kind).value


func validForest(g: Graph; f: SpanningForest): bool {.raises: [].} =
  ## Edges come from the graph, no cycle, same connectivity as the graph, totals add up.
  let n = g.vertexCount
  var parent = newSeq[int](n)
  for v in 0 ..< n: parent[v] = v
  func find(parent: seq[int]; x: int): int {.raises: [].} =
    var c = x
    while parent[c] != c: c = parent[c]
    c
  var total = 0
  let pool = g.edges
  for e in f.edges:
    if e notin pool: return false
    let (a, b) = (find(parent, e.source), find(parent, e.target))
    if a == b: return false
    parent[a] = b
    total += e.weight
  var roots = 0
  for v in 0 ..< n:
    if find(parent, v) == v: roots += 1
  let comps = stronglyConnectedComponents(g)
  for c in comps:
    for v in c:
      if find(parent, v) != find(parent, c[0]): return false
  total == f.totalWeight and f.components == comps.len and roots == comps.len and
    f.edges.len == n - f.components

func cheapestSpanning(g: Graph): int {.raises: [].} =
  ## Oracle: try every subset of edges, keep the cheapest acyclic one that connects what the graph connects.
  let pool = g.edges
  let n = g.vertexCount
  let target = n - stronglyConnectedComponents(g).len
  result = high(int)
  for mask in 0 ..< (1 shl pool.len):
    var parent = newSeq[int](n)
    for v in 0 ..< n: parent[v] = v
    func find(parent: seq[int]; x: int): int {.raises: [].} =
      var c = x
      while parent[c] != c: c = parent[c]
      c
    var taken = 0
    var weight = 0
    var acyclic = true
    for i in 0 ..< pool.len:
      if ((mask shr i) and 1) == 0: continue
      let (a, b) = (find(parent, pool[i].source), find(parent, pool[i].target))
      if a == b:
        acyclic = false
        break
      parent[a] = b
      taken += 1
      weight += pool[i].weight
    if acyclic and taken == target: result = min(result, weight)

# SPEC: GRAPH-KRUSKAL-01
test "GRAPH-KRUSKAL-01 Given any undirected graph, when Kruskal runs, then the result is a spanning forest of the graph":
  let outcome = check(raws(-4, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw, gkUndirected)
    let r = kruskal(g)
    r.isOk and validForest(g, r.value))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-KRUSKAL-02
test "GRAPH-KRUSKAL-02 Given any undirected graph, when Kruskal runs, then its total equals the cheapest forest found by brute force":
  let outcome = check(raws(-4, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw, gkUndirected)
    kruskal(g).value.totalWeight == cheapestSpanning(g))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-KRUSKAL-03
test "GRAPH-KRUSKAL-03 Given any undirected graph, when Kruskal and Prim run, then their total weights agree":
  let outcome = check(raws(-4, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw, gkUndirected)
    let (k, p) = (kruskal(g).value, prim(g).value)
    k.totalWeight == p.totalWeight and k.components == p.components and k.edges.len == p.edges.len)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-KRUSKAL-04
test "GRAPH-KRUSKAL-04 Given a directed graph, when Kruskal runs, then it is refused":
  let g = buildGraph(2, @[edge(0, 1)], gkDirected).value
  check kruskal(g) == err(SpanningForest, geNotUndirected)

# SPEC: GRAPH-KRUSKAL-01
test "GRAPH-KRUSKAL-01 Given a small graph with a cheap detour, when Kruskal runs, then the heavy edge is skipped":
  let g = buildGraph(4, @[edge(0, 1, 1), edge(1, 2, 2), edge(0, 2, 9), edge(2, 3, 4)], gkUndirected).value
  let f = kruskal(g).value
  check f.edges == @[edge(0, 1, 1), edge(1, 2, 2), edge(2, 3, 4)]
  check f.totalWeight == 7
  check f.components == 1

# SPEC: GRAPH-KRUSKAL-01
test "GRAPH-KRUSKAL-01 Given a path of two hundred thousand vertices with edges in the worst union order, when Kruskal runs, then the forest is the whole path":
  var es: seq[Edge]
  for v in 0 ..< 199_999:
    es.add edge(v, v + 1, 199_999 - v)     # the heaviest edge sorts last: unions chain onto one root
  let g = buildGraph(200_000, es, gkUndirected).value
  let f = kruskal(g).value
  check f.edges.len == 199_999
  check f.components == 1
