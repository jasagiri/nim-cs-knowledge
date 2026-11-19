import std/[algorithm, options, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/bfs
import nimcs/algo/scc

type Raw = (int, seq[(int, (int, int))])   # vertex count, [(source, (target, weight))] before reduction mod count

proc raws(minW, maxW: int): Gen[Raw] {.raises: [ValueError].} =
  pair(intIn(1, 7), seqOf(pair(intIn(0, 99), pair(intIn(0, 99), intIn(minW, maxW))), 0, 14))

func edgesOf(raw: Raw): seq[Edge] {.raises: [].} =
  for (u, rest) in raw[1]:
    result.add edge(u mod raw[0], rest[0] mod raw[0], rest[1])

func build(raw: Raw; kind: GraphKind): Graph {.raises: [].} =
  ## The generated edges are always in range, so building cannot fail.
  buildGraph(raw[0], edgesOf(raw), kind).value


func reaches(g: Graph; u, v: int): bool {.raises: [].} =
  bfs(g, u).value.distance(v).isSome

# SPEC: GRAPH-SCC-01
test "GRAPH-SCC-01 Given any graph, when components are found, then they partition the vertices in canonical order":
  let outcome = check(raws(1, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    for kind in [gkDirected, gkUndirected]:
      let comps = stronglyConnectedComponents(build(raw, kind))
      var seen: seq[int]
      for c in comps:
        if c.len == 0 or c != c.sorted: return false
        seen.add c
      var all: seq[int]
      for v in 0 ..< raw[0]: all.add v
      if seen.sorted != all: return false
      for i in 1 ..< comps.len:
        if comps[i - 1][0] >= comps[i][0]: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-SCC-02
test "GRAPH-SCC-02 Given any directed graph, when components are found, then two vertices share one exactly when each reaches the other":
  let outcome = check(raws(1, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw, gkDirected)
    var owner = newSeq[int](g.vertexCount)
    for i, c in stronglyConnectedComponents(g):
      for v in c: owner[v] = i
    for u in 0 ..< g.vertexCount:
      for v in 0 ..< g.vertexCount:
        if (owner[u] == owner[v]) != (g.reaches(u, v) and g.reaches(v, u)): return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-SCC-02
test "GRAPH-SCC-02 Given a small graph with two loops joined by a bridge, when components are found, then each loop is one component":
  let g = buildGraph(6, @[edge(0, 1), edge(1, 2), edge(2, 0), edge(2, 3), edge(3, 4), edge(4, 3)], gkDirected).value
  check stronglyConnectedComponents(g) == @[@[0, 1, 2], @[3, 4], @[5]]
  check stronglyConnectedComponents(buildGraph(0, newSeq[Edge](), gkDirected).value) == newSeq[seq[int]]()
