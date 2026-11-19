## Depth-first search, iterative: follow one branch as far as it goes, then back up.
##
## Use it for reachability, cycle detection, topological order (reverse postorder) and as the first
## pass of strongly connected components. It runs in O(V + E). The explicit stack means a path of
## a million vertices does not overflow the call stack. Neighbours are visited in the graph's
## order, so both orders are deterministic.

import nimcs/fp/result
import nimcs/algo/graph

type DfsOrder* = object
  ## Vertices in the order they were entered (preorder) and left (postorder).
  preorder*: seq[int]
  postorder*: seq[int]

func explore(g: Graph; start: int; visited: var seq[bool]; order: var DfsOrder) {.raises: [].} =
  ## Visits everything reachable from `start` that is not yet visited.
  var stack: seq[(int, int)]    # (vertex, index of its next neighbour to try)
  visited[start] = true
  order.preorder.add start
  stack.add (start, 0)
  while stack.len > 0:
    let (u, next) = stack[^1]
    let arcs = g.neighbors(u)
    if next < arcs.len:
      stack[^1] = (u, next + 1)
      let v = arcs[next].target
      if not visited[v]:
        visited[v] = true
        order.preorder.add v
        stack.add (v, 0)
    else:
      order.postorder.add u
      discard stack.pop

func dfs*(g: Graph; start: int): Result[DfsOrder, GraphError] {.raises: [].} =
  ## The vertices reachable from `start`, in preorder and postorder (GRAPH-DFS-01). Fails when
  ## `start` is not a vertex.
  if not g.inRange(start):
    return err(DfsOrder, geVertexOutOfRange)
  var visited = newSeq[bool](g.vertexCount)
  var order = DfsOrder()
  explore(g, start, visited, order)
  ok(order, GraphError)

func dfsForest*(g: Graph): DfsOrder {.raises: [].} =
  ## A search from vertex 0, then from the smallest vertex not yet visited, and so on, so every
  ## vertex appears exactly once in each order (GRAPH-DFS-02).
  var visited = newSeq[bool](g.vertexCount)
  for v in 0 ..< g.vertexCount:
    if not visited[v]:
      explore(g, v, visited, result)
