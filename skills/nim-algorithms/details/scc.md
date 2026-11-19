# Strongly connected components

## Intent

Two vertices belong to the same strongly connected component when each can reach the other. Kosaraju's algorithm finds the components with two depth-first passes: one on the graph to get the finish order, one on the transposed graph, taking vertices in reverse finish order.

## Use when / avoid when

- Use when: you need mutually recursive modules, deadlock groups, or the acyclic skeleton (condensation) of a directed graph.
- On an undirected graph the same routine returns the connected components.
- Avoid when: you only need to know whether a cycle exists; `topo_sort` answers that directly.

## Nim shape

`src/nimcs/algo/scc.nim`: `stronglyConnectedComponents(g): seq[seq[int]]`, canonical: each component ascending, components ascending by smallest vertex. It reuses `dfsForest` from `dfs.nim` and `transpose` from `graph.nim`.

```nim
import nimcs/algo/graph
import nimcs/algo/scc

let g = buildGraph(5, @[edge(0, 1), edge(1, 0), edge(1, 2), edge(3, 4), edge(4, 3)], gkDirected).value
assert stronglyConnectedComponents(g) == @[@[0, 1], @[2], @[3, 4]]
```

## Laws and invariants

- The components partition the vertices; each is ascending and the list ascends by smallest vertex (GRAPH-SCC-01).
- Two vertices share a component exactly when each reaches the other (GRAPH-SCC-02).

## Complexity

- Time: O(V + E). Space: O(V + E) for the transposed graph.

## Pitfalls

Taking the second pass in finish order instead of reverse finish order, or running it on the original graph instead of the transposed one: the passes then flood into neighbouring components and merge them.

```nim bad
for i in 0 ..< finish.len:            # wrong direction
  let root = finish[i]
  ... walk reachable vertices in g ...  # wrong graph: should be the transpose
```

The fix is `for i in countdown(finish.len - 1, 0)` over the transposed graph.

## Related

- `graph.nim`, `dfs.nim`, `topo_sort.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `61811291625a13a9` Algorithms for Competitive Programming
- `63ad3e14455a34af` Competitive Programmer's Handbook
- `5ea7cdc2c5670fd7` Data Structures and Algorithms
- `6f359b1814ec2eeb` Princeton University Algorithms, Part 2
