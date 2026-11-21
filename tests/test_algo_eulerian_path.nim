import std/[algorithm, options, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/eulerian_path

type Raw = (int, seq[(int, int)])   # vertex count, [(source, target)] before reduction mod count

proc raws(): Gen[Raw] {.raises: [ValueError].} =
  pair(intIn(1, 5), seqOf(pair(intIn(0, 99), intIn(0, 99)), 0, 7))

func build(raw: Raw; kind: GraphKind): Graph {.raises: [].} =
  ## The generated endpoints are reduced into range, so building cannot fail.
  var es: seq[Edge]
  for (u, v) in raw[1]:
    es.add edge(u mod raw[0], v mod raw[0])
  buildGraph(raw[0], es, kind).value

func key(g: Graph; u, v: int): (int, int) {.raises: [].} =
  if g.isDirected or u <= v: (u, v) else: (v, u)

func usesEveryEdgeOnce(g: Graph; trail: seq[int]): bool {.raises: [].} =
  var wanted: seq[(int, int)]
  for e in g.edges:
    wanted.add key(g, e.source, e.target)
  var walked: seq[(int, int)]
  for i in 0 ..< max(trail.len - 1, 0):
    walked.add key(g, trail[i], trail[i + 1])
  wanted.sort
  walked.sort
  wanted == walked and (wanted.len == 0 or trail.len == wanted.len + 1)

func extend(g: Graph; es: seq[Edge]; used: var seq[bool]; at, left, home: int): bool {.raises: [].} =
  ## Backtracking: can the `left` unused edges be walked from `at`, ending at `home` (any vertex when home < 0)?
  if left == 0:
    return home < 0 or at == home
  for i, e in es:
    if used[i]: continue
    var next = -1
    if e.source == at:
      next = e.target
    elif not g.isDirected and e.target == at:
      next = e.source
    if next >= 0:
      used[i] = true
      let found = extend(g, es, used, next, left - 1, home)
      used[i] = false
      if found: return true
  false

func bruteExists(g: Graph; closed: bool): bool {.raises: [].} =
  ## Oracle: try every start vertex and every order of the edges.
  let es = g.edges
  if es.len == 0:
    return true
  var used = newSeq[bool](es.len)
  for v in 0 ..< g.vertexCount:
    if extend(g, es, used, v, es.len, (if closed: v else: -1)):
      return true
  false

# SPEC: GRAPH-EULER-01
test "GRAPH-EULER-01 Given hand-worked graphs, when finding a trail, then the known trails come back":
  let square = buildGraph(4, @[edge(0, 1), edge(1, 2), edge(2, 3), edge(3, 0)], gkUndirected).value
  check eulerianPath(square) == some(@[0, 1, 2, 3, 0])
  let path = buildGraph(3, @[edge(0, 1), edge(1, 2)], gkUndirected).value
  check eulerianPath(path) == some(@[0, 1, 2])
  let ring = buildGraph(3, @[edge(0, 1), edge(1, 2), edge(2, 0)], gkDirected).value
  check eulerianPath(ring) == some(@[0, 1, 2, 0])
  let chain = buildGraph(3, @[edge(1, 2), edge(0, 1)], gkDirected).value
  check eulerianPath(chain) == some(@[0, 1, 2])

# SPEC: GRAPH-EULER-01
test "GRAPH-EULER-01 Given any graph with a trail, when found, then it walks every edge exactly once":
  let outcome = check(raws(), proc(raw: Raw): bool {.raises: [CatchableError].} =
    var ok = true
    for kind in [gkDirected, gkUndirected]:
      let g = build(raw, kind)
      let trail = eulerianPath(g)
      ok = ok and (trail.isNone or usesEveryEdgeOnce(g, trail.get))
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-EULER-02
test "GRAPH-EULER-02 Given any graph, when asked for a trail, then one is found exactly when brute force finds one":
  let outcome = check(raws(), proc(raw: Raw): bool {.raises: [CatchableError].} =
    var ok = true
    for kind in [gkDirected, gkUndirected]:
      let g = build(raw, kind)
      ok = ok and eulerianPath(g).isSome == bruteExists(g, closed = false)
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-EULER-02
test "GRAPH-EULER-02 Given degree or connectivity violations, when asked for a trail, then there is none":
  let star = buildGraph(4, @[edge(0, 1), edge(0, 2), edge(0, 3)], gkUndirected).value   # four odd vertices
  check eulerianPath(star).isNone
  let apart = buildGraph(6, @[edge(0, 1), edge(1, 2), edge(2, 0), edge(3, 4), edge(4, 5), edge(5, 3)],
                         gkUndirected).value                                           # all even, two pieces
  check eulerianPath(apart).isNone
  let fork = buildGraph(3, @[edge(0, 1), edge(0, 2)], gkDirected).value                # two surplus starts
  check eulerianPath(fork).isNone

# SPEC: GRAPH-EULER-03
test "GRAPH-EULER-03 Given any graph, when asked for a circuit, then it is closed and exists exactly when brute force finds a closed trail":
  let outcome = check(raws(), proc(raw: Raw): bool {.raises: [CatchableError].} =
    var ok = true
    for kind in [gkDirected, gkUndirected]:
      let g = build(raw, kind)
      let circuit = eulerianCircuit(g)
      if circuit.isSome:
        let c = circuit.get
        ok = ok and usesEveryEdgeOnce(g, c) and (c.len == 0 or c[0] == c[^1])
      ok = ok and circuit.isSome == bruteExists(g, closed = true)
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-EULER-03
test "GRAPH-EULER-03 Given a graph with an open trail only, when asked for a circuit, then there is none":
  let path = buildGraph(3, @[edge(0, 1), edge(1, 2)], gkUndirected).value
  check eulerianCircuit(path).isNone
  let square = buildGraph(4, @[edge(0, 1), edge(1, 2), edge(2, 3), edge(3, 0)], gkUndirected).value
  check eulerianCircuit(square) == some(@[0, 1, 2, 3, 0])

# SPEC: GRAPH-EULER-04
test "GRAPH-EULER-04 Given parallel edges and self-loops, when finding a trail, then each is walked once":
  let twin = buildGraph(2, @[edge(0, 1), edge(0, 1)], gkUndirected).value
  check eulerianCircuit(twin) == some(@[0, 1, 0])
  let loop = buildGraph(2, @[edge(0, 0), edge(0, 1)], gkUndirected).value
  check usesEveryEdgeOnce(loop, eulerianPath(loop).get)
  let directedLoop = buildGraph(1, @[edge(0, 0)], gkDirected).value
  check eulerianCircuit(directedLoop) == some(@[0, 0])

# SPEC: GRAPH-EULER-05
test "GRAPH-EULER-05 Given a graph without edges, when finding a trail, then the empty trail comes back":
  let g = buildGraph(3, newSeq[Edge](), gkUndirected).value
  check eulerianPath(g) == some(newSeq[int]())
  check eulerianCircuit(g) == some(newSeq[int]())

# SPEC: GRAPH-EULER-06
test "GRAPH-EULER-06 Given any graph, when asked twice, then the trail is the same":
  let outcome = check(raws(), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw, gkUndirected)
    eulerianPath(g) == eulerianPath(g))
  checkpoint describe(outcome)
  check outcome.passed
