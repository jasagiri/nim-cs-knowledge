## Cycle detection, two ways: Floyd's tortoise and hare for a function on a finite set, and a
## depth-first search with three colours for a directed graph.
##
## A function `f` from 0 ..< n to itself, iterated from a start value, must eventually repeat: the
## sequence is a tail of `mu` distinct values followed by a cycle of `lambda` values. Floyd finds
## `mu` and `lambda` with two cursors and O(1) extra memory: a hare moving two steps for every
## step of the tortoise meets it inside the cycle; restarting the tortoise from the start and
## moving both one step at a time makes them meet at the first value of the cycle; walking once
## around the cycle gives its length. Use it for linked lists that may loop and for pseudo-random
## sequences.
##
## The graph search keeps each vertex white (unseen), grey (on the current path) or black (done).
## An arc into a grey vertex closes a cycle; the path from that vertex to the arc's source is the
## cycle. The graph answer agrees with `topoSort` (a directed graph has a cycle exactly when it
## has no topological order); this routine is the cheaper question when no order is wanted.

import std/options
import nimcs/fp/result
import nimcs/algo/graph

type
  Rho* = object
    ## The shape of an iterated function: `tail` distinct values before the cycle, then a cycle of `cycle` values.
    tail*: int
    cycle*: int
    entry*: int    ## the first value of the sequence that lies on the cycle

  CycleError* = enum
    ceNotDirected   ## the graph search is defined for directed graphs only

func `==`*(a, b: Rho): bool {.raises: [].} =
  a.tail == b.tail and a.cycle == b.cycle and a.entry == b.entry

func isTotalOnRange(f: openArray[int]): bool {.raises: [].} =
  for v in f:
    if v < 0 or v >= f.len:
      return false
  true

func floydRho*(f: openArray[int]; start: int): Option[Rho] {.raises: [].} =
  ## The tail length, cycle length and entry value of the sequence start, f[start], f[f[start]], ...
  ## `f[i]` is the image of `i`. None when `start` or any image lies outside 0 ..< f.len, since
  ## then the function is not a self-map of a finite set (CYCLE-FLOYD-01, CYCLE-FLOYD-05).
  if start < 0 or start >= f.len or not isTotalOnRange(f):
    return none(Rho)
  var tortoise = f[start]
  var hare = f[f[start]]
  while tortoise != hare:
    tortoise = f[tortoise]
    hare = f[f[hare]]
  var tail = 0
  tortoise = start
  while tortoise != hare:
    tortoise = f[tortoise]
    hare = f[hare]
    inc tail
  var cycle = 1
  hare = f[tortoise]
  while tortoise != hare:
    hare = f[hare]
    inc cycle
  some(Rho(tail: tail, cycle: cycle, entry: tortoise))

func iterateFunction*(f: openArray[int]; start, steps: int): Option[int] {.raises: [].} =
  ## `f` applied `steps` times to `start`, computed in O(f.len) steps whatever `steps` is, by
  ## using the cycle (CYCLE-FLOYD-03). None for an invalid function or start, or negative steps.
  if steps < 0:
    return none(int)
  let shape = floydRho(f, start)
  if shape.isNone:
    return none(int)
  let rho = shape.get
  var remaining = steps
  if remaining > rho.tail:
    remaining = rho.tail + (steps - rho.tail) mod rho.cycle
  var v = start
  for _ in 0 ..< remaining:
    v = f[v]
  some(v)

func findCycle*(g: Graph): Result[Option[seq[int]], CycleError] {.raises: [].} =
  ## For a directed graph, one directed cycle v0 -> v1 -> ... -> vk -> v0, listed once around and
  ## starting at its smallest vertex, or none when the graph is acyclic (CYCLE-GRAPH-01,
  ## CYCLE-GRAPH-02). A self-loop is a cycle of one vertex. The search visits vertices and
  ## neighbours in ascending order, so the same graph gives the same cycle. An undirected graph
  ## is refused: every undirected edge would be a trivial two-vertex cycle (CYCLE-GRAPH-04).
  if not g.isDirected:
    return err(Option[seq[int]], ceNotDirected)
  let n = g.vertexCount
  var colour = newSeq[int](n)     # 0 white, 1 grey, 2 black
  var nextArc = newSeq[int](n)
  for root in 0 ..< n:
    if colour[root] != 0:
      continue
    var path = @[root]
    colour[root] = 1
    while path.len > 0:
      let u = path[^1]
      if nextArc[u] < g.neighbors(u).len:
        let v = g.neighbors(u)[nextArc[u]].target
        inc nextArc[u]
        if colour[v] == 1:
          var at = path.len - 1
          while path[at] != v:
            dec at
          var cycle = path[at .. ^1]
          var low = 0
          for i, w in cycle:
            if w < cycle[low]: low = i
          cycle = cycle[low .. ^1] & cycle[0 ..< low]
          return ok(some(cycle), CycleError)
        if colour[v] == 0:
          colour[v] = 1
          path.add v
      else:
        colour[u] = 2
        path.delete(path.high)
  ok(none(seq[int]), CycleError)
