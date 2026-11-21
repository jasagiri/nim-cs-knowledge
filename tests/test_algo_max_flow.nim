import std/[algorithm, sequtils, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/max_flow

type Raw = (int, seq[(int, (int, int))])   # vertex count, [(source, (target, capacity))] before reduction mod count

proc raws(): Gen[Raw] {.raises: [ValueError].} =
  pair(intIn(2, 6), seqOf(pair(intIn(0, 99), pair(intIn(0, 99), intIn(0, 9))), 0, 14))

func build(raw: Raw; kind: GraphKind): Graph {.raises: [].} =
  ## The generated edges are always in range, so building cannot fail.
  var es: seq[Edge]
  for (u, rest) in raw[1]:
    es.add edge(u mod raw[0], rest[0] mod raw[0], rest[1])
  buildGraph(raw[0], es, kind).value

func endpoints(n, a, b: int): (int, int) {.raises: [].} =
  ## Two different vertices from two arbitrary numbers.
  let s = a mod n
  (s, (s + 1 + b mod (n - 1)) mod n)

func cutCapacity(g: Graph; inside: seq[bool]): int {.raises: [].} =
  for u in 0 ..< g.vertexCount:
    if inside[u]:
      for a in g.neighbors(u):
        if not inside[a.target]:
          result += a.weight

func minCutByEnumeration(g: Graph; s, t: int): int {.raises: [].} =
  ## The smallest capacity over every vertex set that holds the source and not the sink.
  let n = g.vertexCount
  result = high(int)
  for mask in 0 ..< (1 shl n):
    if ((mask shr s) and 1) == 1 and ((mask shr t) and 1) == 0:
      var inside = newSeq[bool](n)
      for v in 0 ..< n:
        inside[v] = ((mask shr v) and 1) == 1
      result = min(result, cutCapacity(g, inside))

func capacityBetween(g: Graph; u, v: int): int {.raises: [].} =
  for a in g.neighbors(u):
    if a.target == v:
      result += a.weight

func bestMatchingSize(pairs: seq[(int, int)]; leftCount: int): int {.raises: [].} =
  ## Tries, for each left vertex in turn, to leave it alone or to take each still-free right vertex.
  func go(pairs: seq[(int, int)]; l, leftCount: int; used: set[uint8]): int {.raises: [].} =
    if l == leftCount:
      return 0
    result = go(pairs, l + 1, leftCount, used)
    for (a, b) in pairs:
      if a == l and uint8(b) notin used:
        result = max(result, 1 + go(pairs, l + 1, leftCount, used + {uint8(b)}))
  go(pairs, 0, leftCount, {})

# SPEC: GRAPH-MAXFLOW-01
test "GRAPH-MAXFLOW-01 Given the textbook network, when the maximum flow is asked, then it is the known value":
  # s=0, a=1, b=2, c=3, d=4, t=5: the classic network with maximum flow 23.
  let g = buildGraph(6, [edge(0, 1, 16), edge(0, 2, 13), edge(1, 2, 10), edge(2, 1, 4), edge(1, 3, 12),
      edge(3, 2, 9), edge(2, 4, 14), edge(4, 3, 7), edge(3, 5, 20), edge(4, 5, 4)], gkDirected).value
  check maxFlow(g, 0, 5).value.value == 23

# SPEC: GRAPH-MAXFLOW-01
test "GRAPH-MAXFLOW-01 Given a small random graph, when the maximum flow is asked, then it equals the smallest cut found by enumerating all vertex sets":
  let outcome = check(pair(raws(), pair(intIn(0, 99), intIn(0, 99))), proc(c: (Raw, (int, int))): bool {.raises: [CatchableError].} =
    let (raw, ab) = c
    let (s, t) = endpoints(raw[0], ab[0], ab[1])
    for kind in [gkDirected, gkUndirected]:
      let g = build(raw, kind)
      let solved = maxFlow(g, s, t)
      if not solved.isOk or solved.value.value != minCutByEnumeration(g, s, t): return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-MAXFLOW-02
test "GRAPH-MAXFLOW-02 Given any result, when its cut is read, then the source is inside, the sink outside, and the cut's capacity is the flow value":
  let outcome = check(pair(raws(), pair(intIn(0, 99), intIn(0, 99))), proc(c: (Raw, (int, int))): bool {.raises: [CatchableError].} =
    let (raw, ab) = c
    let (s, t) = endpoints(raw[0], ab[0], ab[1])
    let g = build(raw, gkDirected)
    let solved = maxFlow(g, s, t).value
    var inside = newSeq[bool](raw[0])
    for v in solved.sourceSide:
      inside[v] = true
    var capacity = 0
    for e in solved.cut:
      capacity += e.weight
      if not inside[e.source] or inside[e.target]: return false
    inside[s] and not inside[t] and capacity == solved.value and cutCapacity(g, inside) == solved.value)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-MAXFLOW-03
test "GRAPH-MAXFLOW-03 Given any result, when its flows are checked, then no pair exceeds its capacity and every inner vertex keeps what it receives":
  let outcome = check(pair(raws(), pair(intIn(0, 99), intIn(0, 99))), proc(c: (Raw, (int, int))): bool {.raises: [CatchableError].} =
    let (raw, ab) = c
    let (s, t) = endpoints(raw[0], ab[0], ab[1])
    for kind in [gkDirected, gkUndirected]:
      let g = build(raw, kind)
      let solved = maxFlow(g, s, t).value
      var balance = newSeq[int](raw[0])      # inflow minus outflow
      for f in solved.flows:
        if f.weight <= 0 or f.weight > g.capacityBetween(f.source, f.target): return false
        balance[f.target] += f.weight
        balance[f.source] -= f.weight
      for v in 0 ..< raw[0]:
        if v != s and v != t and balance[v] != 0: return false
      if balance[t] != solved.value or balance[s] != -solved.value: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-MAXFLOW-04
test "GRAPH-MAXFLOW-04 Given a bad vertex, equal endpoints or a negative capacity, when asked, then each has its own error":
  let g = buildGraph(3, [edge(0, 1, 2), edge(1, 2, 2)], gkDirected).value
  check maxFlow(g, 0, 3) == err(FlowSolution, feVertexOutOfRange)
  check maxFlow(g, -1, 2) == err(FlowSolution, feVertexOutOfRange)
  check maxFlow(g, 1, 1) == err(FlowSolution, feSameEndpoints)
  let negative = buildGraph(3, [edge(0, 1, -2), edge(1, 2, 2)], gkDirected).value
  check maxFlow(negative, 0, 2) == err(FlowSolution, feNegativeCapacity)

# SPEC: GRAPH-MAXFLOW-05
test "GRAPH-MAXFLOW-05 Given a sink that cannot be reached, when asked, then the flow is zero and the source side is what the source reaches":
  let g = buildGraph(4, [edge(0, 1, 5), edge(2, 3, 5)], gkDirected).value
  let solved = maxFlow(g, 0, 3).value
  check solved.value == 0
  check solved.flows.len == 0
  check solved.sourceSide == @[0, 1]

# SPEC: GRAPH-MAXFLOW-06
test "GRAPH-MAXFLOW-06 Given parallel arcs and opposite arcs, when asked, then capacities add up and opposite arcs do not help each other":
  let parallel = buildGraph(2, [edge(0, 1, 3), edge(0, 1, 4)], gkDirected).value
  check maxFlow(parallel, 0, 1).value.value == 7
  let opposite = buildGraph(2, [edge(0, 1, 3), edge(1, 0, 9)], gkDirected).value
  check maxFlow(opposite, 0, 1).value.value == 3
  let undirected = buildGraph(3, [edge(0, 1, 5), edge(1, 2, 4)], gkUndirected).value
  check maxFlow(undirected, 2, 0).value.value == 4

# SPEC: GRAPH-MATCHING-01
test "GRAPH-MATCHING-01 Given small bipartite graphs, when matched, then the size equals an exhaustive search":
  let outcome = check(seqOf(pair(intIn(0, 3), intIn(0, 3)), 0, 10), proc(pairs: seq[(int, int)]): bool {.raises: [CatchableError].} =
    let m = bipartiteMatching(4, 4, pairs)
    m.isOk and m.value.len == bestMatchingSize(pairs, 4))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-MATCHING-02
test "GRAPH-MATCHING-02 Given any matching, when read, then every pair was offered and no vertex repeats":
  let outcome = check(seqOf(pair(intIn(0, 4), intIn(0, 5)), 0, 14), proc(pairs: seq[(int, int)]): bool {.raises: [CatchableError].} =
    let m = bipartiteMatching(5, 6, pairs).value
    var lefts, rights: seq[int]
    for (l, r) in m:
      if (l, r) notin pairs: return false
      lefts.add l
      rights.add r
    lefts.isSorted and lefts.deduplicate == lefts and rights.deduplicate.len == rights.len)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GRAPH-MATCHING-03
test "GRAPH-MATCHING-03 Given a negative count or a pair outside the sides, when matched, then the error says which kind":
  check bipartiteMatching(-1, 2, newSeq[(int, int)]()) == err(seq[(int, int)], feNegativeCount)
  check bipartiteMatching(2, -1, newSeq[(int, int)]()) == err(seq[(int, int)], feNegativeCount)
  check bipartiteMatching(2, 2, @[(2, 0)]) == err(seq[(int, int)], feVertexOutOfRange)
  check bipartiteMatching(2, 2, @[(0, -1)]) == err(seq[(int, int)], feVertexOutOfRange)
  check bipartiteMatching(0, 0, newSeq[(int, int)]()) == ok(newSeq[(int, int)](), FlowError)

# SPEC: GRAPH-MATCHING-04
test "GRAPH-MATCHING-04 Given a case where a greedy pick fails, when matched, then augmenting finds the perfect matching":
  # Taking 0-0 first blocks 1; the matching 0-1, 1-0 is the only perfect one.
  check bipartiteMatching(2, 2, @[(0, 0), (0, 1), (1, 0)]) == ok(@[(0, 1), (1, 0)], FlowError)
