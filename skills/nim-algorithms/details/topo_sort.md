# Topological sort

## Intent

Order the vertices of a directed acyclic graph so that every arc goes from an earlier to a later vertex. Kahn's algorithm repeatedly takes a vertex with no remaining incoming arcs. If some vertices never become free, they lie on or behind a cycle, and the error carries one cycle. To find it, start at any leftover
vertex and step to one of its leftover predecessors (every leftover vertex still has one) until a
vertex repeats; the vertices from its first visit to the repeat form a cycle.

## Use when / avoid when

- Use when: ordering tasks, build steps, migrations or modules by dependency.
- Use the error value to report which tasks depend on each other in a loop.
- Avoid when: you need groups of mutually dependent vertices; use `scc.nim`.

## Nim shape

`src/nimcs/algo/topo_sort.nim`: `topoSort(g): Result[seq[int], TopoCycle]`. The ready vertices sit in a small `HeapQueue` (`import std/heapqueue`) local to the function, so ties are broken by the smallest vertex and the output is deterministic. The cycle is listed once around, starting at its smallest vertex.

```nim
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/topo_sort

let tasks = buildGraph(4, @[edge(2, 0), edge(2, 3), edge(3, 1)], gkDirected).value
assert topoSort(tasks) == ok(@[2, 0, 3, 1], TopoCycle)

let loop = buildGraph(3, @[edge(0, 1), edge(1, 2), edge(2, 1)], gkDirected).value
assert topoSort(loop).error.vertices == @[1, 2]
```

## Laws and invariants

- On an acyclic graph the result is a permutation of the vertices with every arc pointing forward (GRAPH-TOPO-01).
- On any directed graph the result is a valid order or an error holding a real cycle; self-loops and undirected edges are cycles (GRAPH-TOPO-02).
- The order is the lexicographically smallest valid one (GRAPH-TOPO-03).
- It fails exactly when a strongly connected component has several vertices or a vertex has a self-loop (GRAPH-TOPO-04).

## Complexity

- Time: O((V + E) log V) with the priority queue. Space: O(V).

## Pitfalls

Throwing the cycle away: returning only `false` or an empty list when no order exists leaves the caller with nothing to report.

```nim bad
func topoSort(g: Graph): seq[int] =
  ...
  if order.len < g.vertexCount:
    return @[]            # cycle or empty graph? the caller cannot tell, and learns no vertex
```

The fix is a `Result` whose error names a real cycle, as the module does.

## Related

- `graph.nim`, `dfs.nim`, `scc.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `61811291625a13a9` Algorithms for Competitive Programming
- `63ad3e14455a34af` Competitive Programmer's Handbook
- `5ea7cdc2c5670fd7` Data Structures and Algorithms
- `6f359b1814ec2eeb` Princeton University Algorithms, Part 2
- `81c6122da5a53e33` Principles of Algorithmic Problem Solving
