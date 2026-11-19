# Depth-first search

## Intent

Follow one branch as far as it goes, then back up and try the next. Written with an explicit stack of (vertex, next neighbour index) so a very long path does not overflow the call stack. It records the order vertices are entered (preorder) and left (postorder).

## Use when / avoid when

- Use when: you need reachability, a topological order (reverse postorder of an acyclic graph), cycle detection, or as pass one of `scc`.
- Use `dfsForest` to cover every vertex, including unreachable ones.
- Avoid when: you need fewest-edge paths; use `bfs`.

## Nim shape

`src/nimcs/algo/dfs.nim`: `dfs(g, start): Result[DfsOrder, GraphError]` and `dfsForest(g): DfsOrder`. `DfsOrder` is a plain object with `preorder` and `postorder`.

```nim
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/dfs

let g = buildGraph(4, @[edge(0, 1), edge(0, 2), edge(1, 3)], gkDirected).value
let order = dfs(g, 0).value
assert order.preorder == @[0, 1, 3, 2]
assert order.postorder == @[3, 1, 2, 0]
assert dfsForest(g).preorder.len == 4
```

## Laws and invariants

- `dfs` lists exactly the reachable vertices, the start first in preorder and last in postorder; neighbour order decides ties; it survives a 100 000-vertex path (GRAPH-DFS-01).
- `dfsForest` lists every vertex once in each order (GRAPH-DFS-02).
- On an acyclic graph every arc's head finishes before its tail (GRAPH-DFS-03).

## Complexity

- Time: O(V + E). Space: O(V) for the stack and visited marks.

## Pitfalls

Writing the search recursively: simple, but a path of a few hundred thousand vertices overflows the native stack, and a stack overflow is not a catchable error.

```nim bad
func visit(g: Graph; u: int; seen: var seq[bool]; order: var seq[int]) =
  seen[u] = true
  for a in g.neighbors(u):
    if not seen[a.target]: visit(g, a.target, seen, order)   # depth = path length
  order.add u
```

The fix is the explicit stack of (vertex, next index) pairs the module uses.

## Related

- `graph.nim`, `topo_sort.nim`, `scc.nim`, `bfs.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `6f31dd50eef1beba` Algorithmic Thinking
- `c1b93dc13846e70a` Algorithms Course Materials
- `61811291625a13a9` Algorithms for Competitive Programming
- `a8882bbba7213b23` Algorithms Notes for Professionals
- `b609569e40e49e47` Analysis of Algorithms (CSE 373)
- `63ad3e14455a34af` Competitive Programmer's Handbook
- `e8a751ae9f8ed52b` Learning Algorithm
- `6f359b1814ec2eeb` Princeton University Algorithms, Part 2
