import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/scc
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

# SPEC: GRAPH-PRIM-01
test "GRAPH-PRIM-01 Given any undirected graph, when Prim runs, then the result is a spanning forest of the graph":
  let outcome = check(raws(-4, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw, gkUndirected)
    let r = prim(g)
    r.isOk and validForest(g, r.value))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-PRIM-02
test "GRAPH-PRIM-02 Given a directed graph, when Prim runs, then it is refused":
  let g = buildGraph(2, @[edge(0, 1)], gkDirected).value
  check prim(g) == err(SpanningForest, geNotUndirected)

# SPEC: GRAPH-PRIM-01
test "GRAPH-PRIM-01 Given a small disconnected graph, when Prim runs, then each component gets its own tree":
  let g = buildGraph(6, @[edge(0, 1, 5), edge(1, 2, 1), edge(0, 2, 2), edge(3, 4, 7), edge(4, 4, 1)], gkUndirected).value
  let f = prim(g).value
  check f.edges == @[edge(1, 2, 1), edge(0, 2, 2), edge(3, 4, 7)]
  check f.totalWeight == 10
  check f.components == 3
