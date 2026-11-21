import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/approximation

type Raw = (int, seq[(int, int)])   # vertex count, [(source, target)] before reduction mod count

proc raws(): Gen[Raw] {.raises: [ValueError].} =
  pair(intIn(1, 8), seqOf(pair(intIn(0, 99), intIn(0, 99)), 0, 14))

func build(raw: Raw): Graph {.raises: [].} =
  ## The generated endpoints are reduced into range, so building cannot fail.
  var es: seq[Edge]
  for (u, v) in raw[1]:
    es.add edge(u mod raw[0], v mod raw[0])
  buildGraph(raw[0], es, gkUndirected).value

func coverOf(g: Graph): CoverResult {.raises: [].} =
  maximalMatchingCover(g).value

func optimum(g: Graph): int {.raises: [].} =
  ## Oracle: the size of a smallest cover, by trying every vertex subset.
  result = g.vertexCount
  for mask in 0 ..< (1 shl g.vertexCount):
    var chosen: seq[int]
    for v in 0 ..< g.vertexCount:
      if ((mask shr v) and 1) == 1:
        chosen.add v
    if chosen.len < result and g.isVertexCover(chosen):
      result = chosen.len

# SPEC: APPROX-VC-01
test "APPROX-VC-01 Given any undirected graph, when covering, then every edge has an end in the cover":
  let outcome = check(raws(), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw)
    g.isVertexCover(vertexCover2Approx(g).value))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: APPROX-VC-02
test "APPROX-VC-02 Given any undirected graph, when covering, then the matching is disjoint and the cover has at most twice its size":
  let outcome = check(raws(), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw)
    let r = coverOf(g)
    var seen = newSeq[int](g.vertexCount)
    var ok = r.cover.len <= 2 * r.matching.len
    for e in r.matching:
      ok = ok and g.hasArc(e.source, e.target)
      inc seen[e.source]
      if e.target != e.source:
        inc seen[e.target]
    for count in seen:
      ok = ok and count <= 1          # no vertex is in two matched edges
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: APPROX-VC-03
test "APPROX-VC-03 Given any small graph, when covering, then the cover is at most twice the exact minimum":
  let outcome = check(raws(), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw)
    let found = vertexCover2Approx(g).value.len
    let best = optimum(g)
    found >= best and found <= 2 * best)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: APPROX-VC-04
test "APPROX-VC-04 Given a path on four vertices, when covering, then the ratio of 2 is reached":
  let path = buildGraph(4, @[edge(0, 1), edge(1, 2), edge(2, 3)], gkUndirected).value
  check vertexCover2Approx(path).value == @[0, 1, 2, 3]
  check optimum(path) == 2
  # On a star the first edge covers everything with one hub plus one leaf: 2 against an optimum of 1.
  let star = buildGraph(4, @[edge(0, 1), edge(0, 2), edge(0, 3)], gkUndirected).value
  check vertexCover2Approx(star).value == @[0, 1]
  check optimum(star) == 1

# SPEC: APPROX-VC-05
test "APPROX-VC-05 Given graphs without edges or with self-loops, when covering, then the cover is empty or includes the looped vertex":
  let empty = buildGraph(3, newSeq[Edge](), gkUndirected).value
  check vertexCover2Approx(empty).value.len == 0
  let loop = buildGraph(3, @[edge(1, 1), edge(0, 2)], gkUndirected).value
  check vertexCover2Approx(loop).value == @[0, 1, 2]
  check coverOf(loop).matching.len == 2
  check loop.isVertexCover(vertexCover2Approx(loop).value)

# SPEC: APPROX-VC-06
test "APPROX-VC-06 Given a directed graph, when covering, then it is refused":
  let g = buildGraph(2, @[edge(0, 1)], gkDirected).value
  check maximalMatchingCover(g).error == geNotUndirected
  check vertexCover2Approx(g).isErr

# SPEC: APPROX-VC-07
test "APPROX-VC-07 Given a candidate set, when checking it, then only a set touching every edge is a cover":
  let g = buildGraph(3, @[edge(0, 1), edge(1, 2)], gkUndirected).value
  check g.isVertexCover(@[1])
  check not g.isVertexCover(@[0])
  check not g.isVertexCover(newSeq[int]())
  check not g.isVertexCover(@[7, -1])       # vertices outside the graph never help
  check g.isVertexCover(@[0, 2])

# SPEC: APPROX-VC-08
test "APPROX-VC-08 Given the same graph twice, when covering, then the cover and matching repeat":
  let outcome = check(raws(), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw)
    let a = coverOf(g)
    let b = coverOf(build(raw))
    a.cover == b.cover and a.matching == b.matching)
  checkpoint describe(outcome)
  check outcome.passed
