## Strongly connected components (Kosaraju): groups of vertices that can all reach each other.
##
## Use it to collapse a directed graph into its acyclic skeleton, find mutually recursive modules
## or deadlock groups. The algorithm is two depth-first passes: one on the graph to get the finish
## order, one on the transposed graph in reverse finish order. O(V + E). On an undirected graph it
## gives the connected components. Output is canonical: each component ascending, components in
## ascending order of their smallest vertex.

import std/algorithm
import nimcs/algo/graph
import nimcs/algo/dfs

func stronglyConnectedComponents*(g: Graph): seq[seq[int]] {.raises: [].} =
  ## Partition of all vertices into components (GRAPH-SCC-01): two vertices share a component
  ## exactly when each reaches the other (GRAPH-SCC-02).
  let n = g.vertexCount
  let reversed = g.transpose
  let finish = dfsForest(g).postorder
  var visited = newSeq[bool](n)
  for i in countdown(finish.len - 1, 0):
    let root = finish[i]
    if visited[root]: continue
    visited[root] = true
    var component: seq[int]
    var stack = @[root]
    while stack.len > 0:
      let u = stack.pop
      component.add u
      for a in reversed.neighbors(u):
        if not visited[a.target]:
          visited[a.target] = true
          stack.add a.target
    component.sort
    result.add component
  result.sort(proc(a, b: seq[int]): int = cmp(a[0], b[0]))
