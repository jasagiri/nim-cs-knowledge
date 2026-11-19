import std/[algorithm, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/graph

type Raw = (int, seq[(int, (int, int))])   # vertex count, [(source, (target, weight))] before reduction mod count

proc raws(minW, maxW: int): Gen[Raw] {.raises: [ValueError].} =
  pair(intIn(1, 7), seqOf(pair(intIn(0, 99), pair(intIn(0, 99), intIn(minW, maxW))), 0, 14))

func edgesOf(raw: Raw): seq[Edge] {.raises: [].} =
  for (u, rest) in raw[1]:
    result.add edge(u mod raw[0], rest[0] mod raw[0], rest[1])

func build(raw: Raw; kind: GraphKind): Graph {.raises: [].} =
  ## The generated edges are always in range, so building cannot fail.
  buildGraph(raw[0], edgesOf(raw), kind).value

# SPEC: GRAPH-BUILD-01
test "GRAPH-BUILD-01 Given the same edges in another order, when graphs are built, then the graphs are equal":
  let outcome = check(raws(-3, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let es = edgesOf(raw)
    buildGraph(raw[0], es, gkDirected) == buildGraph(raw[0], es.reversed, gkDirected) and
      buildGraph(raw[0], es, gkUndirected) == buildGraph(raw[0], es.reversed, gkUndirected))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-BUILD-02
test "GRAPH-BUILD-02 Given a bad vertex count or an endpoint out of range, when a graph is built, then the matching error is returned":
  check buildGraph(-1, newSeq[Edge](), gkDirected) == err(Graph, geNegativeOrder)
  check buildGraph(3, @[edge(0, 3)], gkDirected) == err(Graph, geVertexOutOfRange)
  check buildGraph(3, @[edge(-1, 0)], gkUndirected) == err(Graph, geVertexOutOfRange)
  check buildGraph(0, newSeq[Edge](), gkDirected).isOk

# SPEC: GRAPH-BUILD-03
test "GRAPH-BUILD-03 Given any graph, when its edges are listed and rebuilt, then the same graph results":
  let outcome = check(raws(-3, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let d = build(raw, gkDirected)
    let u = build(raw, gkUndirected)
    buildGraph(raw[0], d.edges, gkDirected) == ok(d, GraphError) and
      buildGraph(raw[0], u.edges, gkUndirected) == ok(u, GraphError) and
      d.edges.len == raw[1].len and u.edges.len == raw[1].len)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-BUILD-04
test "GRAPH-BUILD-04 Given any graph, when neighbours are read, then they ascend by target then weight":
  let outcome = check(raws(-3, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw, gkUndirected)
    for v in 0 ..< g.vertexCount:
      let arcs = g.neighbors(v)
      for i in 1 ..< arcs.len:
        if (arcs[i - 1].target, arcs[i - 1].weight) > (arcs[i].target, arcs[i].weight): return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-BUILD-05
test "GRAPH-BUILD-05 Given an undirected graph, when arcs are asked about, then every arc has its reverse":
  let outcome = check(raws(-3, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw, gkUndirected)
    for u in 0 ..< g.vertexCount:
      for v in 0 ..< g.vertexCount:
        if g.hasArc(u, v) != g.hasArc(v, u): return false
    not g.isDirected)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-BUILD-05
test "GRAPH-BUILD-05 Given a directed edge, when arcs are asked about, then only its own direction exists":
  let g = buildGraph(3, @[edge(0, 1), edge(2, 2)], gkDirected).value
  check g.hasArc(0, 1)
  check not g.hasArc(1, 0)
  check g.hasArc(2, 2)
  check not g.hasArc(0, 5)
  check g.arcCount == 2

# SPEC: GRAPH-TRANSPOSE-01
test "GRAPH-TRANSPOSE-01 Given any graph, when transposed, then every arc is reversed and transposing twice gives the graph back":
  let outcome = check(raws(-3, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw, gkDirected)
    let t = g.transpose
    for u in 0 ..< g.vertexCount:
      for v in 0 ..< g.vertexCount:
        if g.hasArc(u, v) != t.hasArc(v, u): return false
    t.transpose == g and t.arcCount == g.arcCount and
      build(raw, gkUndirected).transpose == build(raw, gkUndirected))
  checkpoint describe(outcome)
  check outcome.passed
