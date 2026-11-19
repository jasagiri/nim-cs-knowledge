import std/[options, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/bellman_ford
import nimcs/algo/dijkstra

type Raw = (int, seq[(int, (int, int))])   # vertex count, [(source, (target, weight))] before reduction mod count

proc raws(minW, maxW: int): Gen[Raw] {.raises: [ValueError].} =
  pair(intIn(1, 7), seqOf(pair(intIn(0, 99), pair(intIn(0, 99), intIn(minW, maxW))), 0, 14))

func edgesOf(raw: Raw): seq[Edge] {.raises: [].} =
  for (u, rest) in raw[1]:
    result.add edge(u mod raw[0], rest[0] mod raw[0], rest[1])

func build(raw: Raw; kind: GraphKind): Graph {.raises: [].} =
  ## The generated edges are always in range, so building cannot fail.
  buildGraph(raw[0], edgesOf(raw), kind).value


func pathWeight(g: Graph; path: seq[int]): Option[int] {.raises: [].} =
  ## Total weight along `path`, taking the cheapest parallel arc at each step; none if a step is missing.
  var total = 0
  for i in 1 ..< path.len:
    var best = none(int)
    for a in g.neighbors(path[i - 1]):
      if a.target == path[i] and (best.isNone or a.weight < best.get): best = some(a.weight)
    if best.isNone: return none(int)
    total += best.get
  some(total)

# SPEC: GRAPH-DIJKSTRA-01
test "GRAPH-DIJKSTRA-01 Given non-negative weights, when searched, then distances equal Bellman-Ford's":
  let outcome = check(pair(raws(0, 9), intIn(0, 6)), proc(c: (Raw, int)): bool {.raises: [CatchableError].} =
    let (raw, s) = c
    let source = s mod raw[0]
    for kind in [gkDirected, gkUndirected]:
      let g = build(raw, kind)
      let d = dijkstra(g, source)
      let b = bellmanFord(g, source)
      if not d.isOk or not b.isOk or d.value.dist != b.value.dist: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-DIJKSTRA-01
test "GRAPH-DIJKSTRA-01 Given a reachable vertex, when its path is read, then the path's weight is the distance":
  let outcome = check(pair(raws(0, 9), intIn(0, 6)), proc(c: (Raw, int)): bool {.raises: [CatchableError].} =
    let (raw, s) = c
    let source = s mod raw[0]
    let g = build(raw, gkDirected)
    let t = dijkstra(g, source).value
    for v in 0 ..< g.vertexCount:
      let p = t.pathTo(v)
      if p.isSome != t.distance(v).isSome: return false
      if p.isSome and (p.get[0] != source or p.get[^1] != v or g.pathWeight(p.get) != t.distance(v)): return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-DIJKSTRA-01
test "GRAPH-DIJKSTRA-01 Given a small weighted graph, when searched from 0, then the cheaper detour wins":
  let g = buildGraph(5, @[edge(0, 1, 10), edge(0, 2, 3), edge(2, 1, 4), edge(1, 3, 2), edge(2, 3, 20)], gkDirected).value
  let t = dijkstra(g, 0).value
  check t.distance(1) == some(7)
  check t.distance(3) == some(9)
  check t.pathTo(3) == some(@[0, 2, 1, 3])
  check t.distance(4).isNone

# SPEC: GRAPH-DIJKSTRA-02
test "GRAPH-DIJKSTRA-02 Given a negative arc or a bad source, when searched, then the matching error is returned":
  let g = buildGraph(3, @[edge(0, 1, 2), edge(1, 2, -1)], gkDirected).value
  check dijkstra(g, 0) == err(PathTree, geNegativeWeight)
  check dijkstra(g, 3) == err(PathTree, geVertexOutOfRange)
  let outcome = check(pair(raws(-5, -1), intIn(0, 6)), proc(c: (Raw, int)): bool {.raises: [CatchableError].} =
    let (raw, s) = c
    raw[1].len == 0 or dijkstra(build(raw, gkDirected), s mod raw[0]) == err(PathTree, geNegativeWeight))
  checkpoint describe(outcome)
  check outcome.passed
