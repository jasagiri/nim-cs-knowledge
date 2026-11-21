import std/[options, sets, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/topo_sort
import nimcs/algo/cycle_detection

type Raw = (int, seq[(int, (int, int))])   # vertex count, [(source, (target, weight))] before reduction mod count

proc raws(): Gen[Raw] {.raises: [ValueError].} =
  pair(intIn(1, 7), seqOf(pair(intIn(0, 99), pair(intIn(0, 99), intIn(1, 1))), 0, 12))

func build(raw: Raw; kind: GraphKind): Graph {.raises: [].} =
  ## The generated edges are always in range, so building cannot fail.
  var es: seq[Edge]
  for (u, rest) in raw[1]:
    es.add edge(u mod raw[0], rest[0] mod raw[0], rest[1])
  buildGraph(raw[0], es, kind).value

proc tables(): Gen[(seq[int], int)] {.raises: [ValueError].} =
  ## A function table on 0 ..< n (values reduced mod n) and a start (reduced mod n).
  pair(seqOf(intIn(0, 99), 1, 12), intIn(0, 99))

func naiveRho(f: seq[int]; start: int): Rho {.raises: [].} =
  ## Oracle: remember the step at which each value was first seen.
  var firstSeen = newSeq[int](f.len)
  for i in 0 ..< f.len:
    firstSeen[i] = -1
  var v = start
  var step = 0
  while firstSeen[v] < 0:
    firstSeen[v] = step
    v = f[v]
    inc step
  Rho(tail: firstSeen[v], cycle: step - firstSeen[v], entry: v)

func reduced(raw: (seq[int], int)): (seq[int], int) {.raises: [].} =
  var f: seq[int]
  for v in raw[0]:
    f.add v mod raw[0].len
  (f, raw[1] mod raw[0].len)

func stepped(f: seq[int]; start, steps: int): int {.raises: [].} =
  result = start
  for _ in 0 ..< steps:
    result = f[result]

func isCycleOf(g: Graph; cycle: seq[int]): bool {.raises: [].} =
  if cycle.len == 0 or cycle.toHashSet.len != cycle.len:
    return false
  for i in 0 ..< cycle.len:
    if not g.hasArc(cycle[i], cycle[(i + 1) mod cycle.len]):
      return false
  cycle[0] == min(cycle)

# SPEC: CYCLE-FLOYD-01
test "CYCLE-FLOYD-01 Given hand-worked sequences, when running Floyd, then tail, cycle and entry are the known values":
  # 0 -> 1 -> 2 -> 3 -> 4 -> 2 : tail 2, cycle 3, entry 2
  check floydRho(@[1, 2, 3, 4, 2], 0) == some(Rho(tail: 2, cycle: 3, entry: 2))
  check floydRho(@[0], 0) == some(Rho(tail: 0, cycle: 1, entry: 0))
  check floydRho(@[1, 0], 0) == some(Rho(tail: 0, cycle: 2, entry: 0))
  check floydRho(@[1, 2, 2], 0) == some(Rho(tail: 2, cycle: 1, entry: 2))

# SPEC: CYCLE-FLOYD-01
test "CYCLE-FLOYD-01 Given any function table and start, when running Floyd, then it equals the first-seen-step oracle":
  let outcome = check(tables(), proc(raw: (seq[int], int)): bool {.raises: [CatchableError].} =
    let (f, start) = reduced(raw)
    floydRho(f, start) == some(naiveRho(f, start)))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: CYCLE-FLOYD-02
test "CYCLE-FLOYD-02 Given any function table, when running Floyd, then the entry is reached after the tail and returns after one cycle":
  let outcome = check(tables(), proc(raw: (seq[int], int)): bool {.raises: [CatchableError].} =
    let (f, start) = reduced(raw)
    let rho = floydRho(f, start).get
    var ok = stepped(f, start, rho.tail) == rho.entry
    ok = ok and stepped(f, rho.entry, rho.cycle) == rho.entry
    ok = ok and rho.tail + rho.cycle <= f.len and rho.cycle >= 1
    for k in 1 ..< rho.cycle:
      ok = ok and stepped(f, rho.entry, k) != rho.entry
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: CYCLE-FLOYD-03
test "CYCLE-FLOYD-03 Given a huge step count, when iterating, then the answer equals stepping one at a time":
  let outcome = check(tables(), proc(raw: (seq[int], int)): bool {.raises: [CatchableError].} =
    let (f, start) = reduced(raw)
    var ok = true
    for steps in 0 .. 30:
      ok = ok and iterateFunction(f, start, steps) == some(stepped(f, start, steps))
    ok)
  checkpoint describe(outcome)
  check outcome.passed
  check iterateFunction(@[1, 2, 0], 0, 1_000_000_000_000) == some(1)
  check iterateFunction(@[1, 2, 0], 0, -1).isNone

# SPEC: CYCLE-FLOYD-04
test "CYCLE-FLOYD-04 Given a permutation, when running Floyd from any start, then there is no tail":
  check floydRho(@[2, 0, 1, 3], 1) == some(Rho(tail: 0, cycle: 3, entry: 1))
  check floydRho(@[2, 0, 1, 3], 3) == some(Rho(tail: 0, cycle: 1, entry: 3))
  let outcome = check(intIn(1, 8), proc(n: int): bool {.raises: [CatchableError].} =
    var shift: seq[int]
    for i in 0 ..< n:
      shift.add (i + 3) mod n    # a rotation is a permutation
    floydRho(shift, 0).get.tail == 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: CYCLE-FLOYD-05
test "CYCLE-FLOYD-05 Given an image or start outside the set, when running Floyd, then the answer is none":
  check floydRho(@[1, 5, 0], 0).isNone
  check floydRho(@[1, -1, 0], 0).isNone
  check floydRho(@[1, 0], 2).isNone
  check floydRho(@[1, 0], -1).isNone
  check floydRho(newSeq[int](), 0).isNone

# SPEC: CYCLE-GRAPH-01
test "CYCLE-GRAPH-01 Given any directed graph, when a cycle is found, then it is a real cycle listed from its smallest vertex":
  let outcome = check(raws(), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw, gkDirected)
    let found = findCycle(g).value
    found.isNone or isCycleOf(g, found.get))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: CYCLE-GRAPH-02
test "CYCLE-GRAPH-02 Given any directed graph, when searched, then a cycle exists exactly when topological sorting fails":
  let outcome = check(raws(), proc(raw: Raw): bool {.raises: [CatchableError].} =
    let g = build(raw, gkDirected)
    findCycle(g).value.isSome == topoSort(g).isErr)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: CYCLE-GRAPH-03
test "CYCLE-GRAPH-03 Given known graphs and repeated calls, when searched, then the same cycle comes back":
  let selfLoop = buildGraph(3, @[edge(0, 1), edge(1, 1)], gkDirected).value
  check findCycle(selfLoop).value == some(@[1])
  let loop = buildGraph(4, @[edge(0, 1), edge(1, 2), edge(2, 3), edge(3, 1)], gkDirected).value
  check findCycle(loop).value == some(@[1, 2, 3])
  let dag = buildGraph(4, @[edge(0, 1), edge(0, 2), edge(1, 3), edge(2, 3)], gkDirected).value
  check findCycle(dag).value.isNone
  check findCycle(loop) == findCycle(loop)

# SPEC: CYCLE-GRAPH-04
test "CYCLE-GRAPH-04 Given an undirected graph, when searching for a cycle, then it is refused":
  let g = buildGraph(2, @[edge(0, 1)], gkUndirected).value
  check findCycle(g).error == ceNotDirected
