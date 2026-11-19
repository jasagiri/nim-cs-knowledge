import std/[algorithm, options, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/bfs
import nimcs/algo/dfs

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

func positions(order: seq[int]; n: int): seq[int] {.raises: [].} =
  result = newSeq[int](n)
  for i, v in order: result[v] = i

# SPEC: GRAPH-DFS-01
test "GRAPH-DFS-01 Given any graph and start, when searched depth first, then both orders list exactly the reachable vertices, the start first in preorder and last in postorder":
  let outcome = check(pair(raws(1, 9), intIn(0, 6)), proc(c: (Raw, int)): bool {.raises: [CatchableError].} =
    let (raw, s) = c
    let start = s mod raw[0]
    let g = build(raw, gkDirected)
    let order = dfs(g, start).value
    let reached = bfs(g, start).value
    var expected: seq[int]
    for v in 0 ..< g.vertexCount:
      if reached.distance(v).isSome: expected.add v
    order.preorder.sorted == expected and order.postorder.sorted == expected and
      order.preorder[0] == start and order.postorder[^1] == start)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-DFS-01
test "GRAPH-DFS-01 Given a small graph, when searched from 0, then the orders follow neighbour order":
  let g = buildGraph(5, @[edge(0, 1), edge(0, 2), edge(1, 3), edge(2, 3), edge(3, 4)], gkDirected).value
  let order = dfs(g, 0).value
  check order.preorder == @[0, 1, 3, 4, 2]
  check order.postorder == @[4, 3, 1, 2, 0]
  check dfs(g, 5) == err(DfsOrder, geVertexOutOfRange)

# SPEC: GRAPH-DFS-01
test "GRAPH-DFS-01 Given a path of a hundred thousand vertices, when searched, then the search finishes without recursion trouble":
  var es: seq[Edge]
  for v in 0 ..< 99_999:
    es.add edge(v, v + 1)
  let g = buildGraph(100_000, es, gkDirected).value
  let order = dfs(g, 0).value
  check order.preorder.len == 100_000
  check order.postorder[0] == 99_999

# SPEC: GRAPH-DFS-02
test "GRAPH-DFS-02 Given any graph, when a forest search runs, then every vertex appears exactly once in each order":
  let outcome = check(raws(1, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    var all: seq[int]
    for v in 0 ..< raw[0]: all.add v
    for kind in [gkDirected, gkUndirected]:
      let order = dfsForest(build(raw, kind))
      if order.preorder.sorted != all or order.postorder.sorted != all: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-DFS-03
test "GRAPH-DFS-03 Given an acyclic graph, when a forest search runs, then every arc's head finishes before its tail":
  let outcome = check(raws(1, 9), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = dagOf(raw)
    let finish = positions(dfsForest(g).postorder, g.vertexCount)
    for u in 0 ..< g.vertexCount:
      for a in g.neighbors(u):
        if finish[a.target] >= finish[u]: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed
