import std/[options, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/bellman_ford
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


func cycleWeight(g: Graph; cycle: seq[int]): Option[int] {.raises: [].} =
  ## Weight of the cheapest way round `cycle`; none if an arc is missing.
  var total = 0
  for i in 0 ..< cycle.len:
    let (u, v) = (cycle[i], cycle[(i + 1) mod cycle.len])
    var best = none(int)
    for a in g.neighbors(u):
      if a.target == v and (best.isNone or a.weight < best.get): best = some(a.weight)
    if best.isNone: return none(int)
    total += best.get
  some(total)

# SPEC: GRAPH-BELLMAN-01
test "GRAPH-BELLMAN-01 Given weights that may be negative and no negative cycle, when searched, then distances equal Floyd-Warshall's row":
  let outcome = check(pair(raws(-3, 9), intIn(0, 6)), proc(c: (Raw, int)): bool {.raises: [CatchableError].} =
    let (raw, s) = c
    let source = s mod raw[0]
    let g = build(raw, gkDirected)
    let all = floydWarshall(g)
    if not all.isOk: return true
    let b = bellmanFord(g, source)
    if not b.isOk: return false
    for v in 0 ..< g.vertexCount:
      if b.value.distance(v) != all.value.distance(source, v): return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-BELLMAN-01
test "GRAPH-BELLMAN-01 Given a negative arc without a cycle, when searched, then the negative route is found":
  let g = buildGraph(4, @[edge(0, 1, 4), edge(0, 2, 5), edge(2, 1, -3), edge(1, 3, 1)], gkDirected).value
  let t = bellmanFord(g, 0).value
  check t.distance(1) == some(2)
  check t.distance(3) == some(3)
  check t.pathTo(3) == some(@[0, 2, 1, 3])
  check bellmanFord(g, 4).error.kind == bfBadSource

# SPEC: GRAPH-BELLMAN-02
test "GRAPH-BELLMAN-02 Given any graph, when a negative cycle is reported, then the cycle is real and negative":
  let outcome = check(pair(raws(-6, 6), intIn(0, 6)), proc(c: (Raw, int)): bool {.raises: [CatchableError].} =
    let (raw, s) = c
    for kind in [gkDirected, gkUndirected]:
      let g = build(raw, kind)
      let b = bellmanFord(g, s mod raw[0])
      if b.isErr:
        let w = g.cycleWeight(b.error.cycle)
        if b.error.kind != bfNegativeCycle or b.error.cycle.len == 0 or w.isNone or w.get >= 0: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

func cycleReachable(g: Graph; source: int): bool {.raises: [].} =
  ## Oracle, independent of Bellman-Ford: full Floyd-Warshall (no early stop; n <= 7 and small
  ## weights keep the numbers far from overflow), then "some vertex v with a negative closed walk
  ## is reachable from source".
  let n = g.vertexCount
  var has = newSeq[bool](n * n)
  var d = newSeq[int](n * n)
  for v in 0 ..< n:
    has[v * n + v] = true
  for u in 0 ..< n:
    for a in g.neighbors(u):
      let at = u * n + a.target
      if not has[at] or a.weight < d[at] or (u == a.target and a.weight < d[at]):
        has[at] = true
        d[at] = a.weight
  for k in 0 ..< n:
    for i in 0 ..< n:
      for j in 0 ..< n:
        if has[i * n + k] and has[k * n + j] and
            (not has[i * n + j] or d[i * n + k] + d[k * n + j] < d[i * n + j]):
          has[i * n + j] = true
          d[i * n + j] = d[i * n + k] + d[k * n + j]
  for v in 0 ..< n:
    if has[source * n + v] and d[v * n + v] < 0: return true
  false

# SPEC: GRAPH-BELLMAN-02
test "GRAPH-BELLMAN-02 Given any graph and source, when searched, then a negative cycle is reported exactly when one is reachable from that source":
  let outcome = check(pair(raws(-6, 6), intIn(0, 6)), proc(c: (Raw, int)): bool {.raises: [CatchableError].} =
    let (raw, s) = c
    for kind in [gkDirected, gkUndirected]:
      let g = build(raw, kind)
      let source = s mod raw[0]
      if bellmanFord(g, source).isErr != g.cycleReachable(source): return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-BELLMAN-02
test "GRAPH-BELLMAN-02 Given a small negative loop, when searched from before and beside it, then it is found or ignored accordingly":
  let g = buildGraph(4, @[edge(0, 1, 1), edge(1, 2, -2), edge(2, 1, 1), edge(3, 3, 5)], gkDirected).value
  check bellmanFord(g, 0).error.cycle == @[1, 2]
  check bellmanFord(g, 3).isOk
