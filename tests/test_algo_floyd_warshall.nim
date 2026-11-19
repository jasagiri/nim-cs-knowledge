import std/[options, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/bellman_ford
import nimcs/algo/dijkstra
import nimcs/algo/floyd_warshall

type Raw = (int, seq[(int, (int, int))])   # vertex count, [(source, (target, weight))] before reduction mod count

proc raws(minW, maxW: int): Gen[Raw] {.raises: [ValueError].} =
  pair(intIn(1, 7), seqOf(pair(intIn(0, 99), pair(intIn(0, 99), intIn(minW, maxW))), 0, 14))

func edgesOf(raw: Raw): seq[Edge] {.raises: [].} =
  for (u, rest) in raw[1]:
    result.add edge(u mod raw[0], rest[0] mod raw[0], rest[1])

func build(raw: Raw; kind: GraphKind): Graph {.raises: [].} =
  ## The generated edges are always in range, so building cannot fail.
  buildGraph(raw[0], edgesOf(raw), kind).value


# SPEC: GRAPH-FLOYD-01
test "GRAPH-FLOYD-01 Given non-negative weights, when all pairs are computed, then every row equals Dijkstra from that source":
  let outcome = check(raws(0, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    for kind in [gkDirected, gkUndirected]:
      let g = build(raw, kind)
      let all = floydWarshall(g)
      if not all.isOk: return false
      for s in 0 ..< g.vertexCount:
        let t = dijkstra(g, s).value
        for v in 0 ..< g.vertexCount:
          if all.value.distance(s, v) != t.distance(v): return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-FLOYD-01
test "GRAPH-FLOYD-01 Given a small graph, when all pairs are computed, then distances are the expected ones and outside vertices have none":
  let g = buildGraph(4, @[edge(0, 1, 3), edge(1, 2, -1), edge(0, 2, 5)], gkDirected).value
  let all = floydWarshall(g).value
  check all.distance(0, 2) == some(2)
  check all.distance(2, 0).isNone
  check all.distance(3, 3) == some(0)
  check all.distance(0, 4).isNone
  check all.distance(-1, 0).isNone

# SPEC: GRAPH-FLOYD-02
test "GRAPH-FLOYD-02 Given any graph, when all pairs are computed, then it fails exactly when some source sees a negative cycle":
  let outcome = check(raws(-6, 6), proc(raw: Raw): bool {.raises: [CatchableError].} =
    for kind in [gkDirected, gkUndirected]:
      let g = build(raw, kind)
      var anyFails = false
      for s in 0 ..< g.vertexCount:
        if bellmanFord(g, s).isErr: anyFails = true
      if floydWarshall(g).isErr != anyFails: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-FLOYD-02
test "GRAPH-FLOYD-02 Given a negative self-loop, when all pairs are computed, then the error names that vertex":
  let g = buildGraph(3, @[edge(0, 1, 1), edge(2, 2, -1)], gkDirected).value
  check floydWarshall(g).error.vertex == 2

# SPEC: GRAPH-FLOYD-03
test "GRAPH-FLOYD-03 Given any pair, when its path is read, then it runs along real arcs with the distance as its weight, or is none when unreachable":
  let outcome = check(raws(-3, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw, gkDirected)
    let r = floydWarshall(g)
    if not r.isOk: return true
    for u in 0 ..< g.vertexCount:
      for v in 0 ..< g.vertexCount:
        let p = r.value.pathBetween(u, v)
        if p.isSome != r.value.distance(u, v).isSome: return false
        if p.isNone: continue
        let path = p.get
        if path[0] != u or path[^1] != v: return false
        var total = 0
        for i in 1 ..< path.len:
          var best = none(int)
          for a in g.neighbors(path[i - 1]):
            if a.target == path[i] and (best.isNone or a.weight < best.get): best = some(a.weight)
          if best.isNone: return false
          total += best.get
        if some(total) != r.value.distance(u, v): return false
    true)
  checkpoint describe(outcome)
  check outcome.passed
