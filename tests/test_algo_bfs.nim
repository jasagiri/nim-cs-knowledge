import std/[options, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/bfs

type Raw = (int, seq[(int, (int, int))])   # vertex count, [(source, (target, weight))] before reduction mod count

proc raws(minW, maxW: int): Gen[Raw] {.raises: [ValueError].} =
  pair(intIn(1, 7), seqOf(pair(intIn(0, 99), pair(intIn(0, 99), intIn(minW, maxW))), 0, 14))

func edgesOf(raw: Raw): seq[Edge] {.raises: [].} =
  for (u, rest) in raw[1]:
    result.add edge(u mod raw[0], rest[0] mod raw[0], rest[1])

func build(raw: Raw; kind: GraphKind): Graph {.raises: [].} =
  ## The generated edges are always in range, so building cannot fail.
  buildGraph(raw[0], edgesOf(raw), kind).value

func hops(g: Graph; source: int): seq[Option[int]] {.raises: [].} =
  ## Oracle: relax "one more edge" until nothing improves.
  result = newSeq[Option[int]](g.vertexCount)
  result[source] = some(0)
  var changed = true
  while changed:
    changed = false
    for u in 0 ..< g.vertexCount:
      if result[u].isNone: continue
      for a in g.neighbors(u):
        if result[a.target].isNone or result[u].get + 1 < result[a.target].get:
          result[a.target] = some(result[u].get + 1)
          changed = true

# SPEC: GRAPH-BFS-01
test "GRAPH-BFS-01 Given any graph and source, when searched breadth first, then distances are the fewest edges":
  let outcome = check(pair(raws(1, 9), intIn(0, 6)), proc(c: (Raw, int)): bool {.raises: [CatchableError].} =
    let (raw, s) = c
    let source = s mod raw[0]
    for kind in [gkDirected, gkUndirected]:
      let g = build(raw, kind)
      let tree = bfs(g, source)
      if not tree.isOk or tree.value.dist != hops(g, source): return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-BFS-01
test "GRAPH-BFS-01 Given a small graph, when searched from 0, then distances and parents are the expected ones":
  let g = buildGraph(6, @[edge(0, 1), edge(0, 2), edge(1, 3), edge(2, 3), edge(3, 4)], gkDirected).value
  let t = bfs(g, 0).value
  check t.distance(4) == some(3)
  check t.distance(5).isNone
  check t.parent[3] == some(1)      # the smaller of the two equally short ways in
  check bfs(g, 6) == err(PathTree, geVertexOutOfRange)
  check bfs(g, -1) == err(PathTree, geVertexOutOfRange)

# SPEC: GRAPH-PATH-01
test "GRAPH-PATH-01 Given any reachable vertex, when its path is read, then it runs source to vertex along real arcs with the right length":
  let outcome = check(pair(raws(1, 9), intIn(0, 6)), proc(c: (Raw, int)): bool {.raises: [CatchableError].} =
    let (raw, s) = c
    let source = s mod raw[0]
    let g = build(raw, gkDirected)
    let t = bfs(g, source).value
    for v in 0 ..< g.vertexCount:
      let p = t.pathTo(v)
      if t.distance(v).isNone:
        if p.isSome: return false
        continue
      if p.isNone: return false
      let path = p.get
      if path[0] != source or path[^1] != v or path.len != t.distance(v).get + 1: return false
      for i in 1 ..< path.len:
        if not g.hasArc(path[i - 1], path[i]): return false
    t.pathTo(raw[0]).isNone)
  checkpoint describe(outcome)
  check outcome.passed
