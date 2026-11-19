# Dijkstra's shortest paths

## Intent

Keep the best known distance to every vertex and repeatedly settle the unsettled vertex with the smallest distance. Because no weight is negative, a settled vertex can never be improved later. A binary heap with lazy deletion picks the next vertex quickly.

## Use when / avoid when

- Use when: all weights are non-negative and you want shortest paths from one source (travel time, price).
- Avoid when: any weight is negative: this refuses the graph with `geNegativeWeight`; use `bellman_ford`.
- Avoid when: you need all pairs on a small dense graph; `floyd_warshall` is simpler.
- Avoid when: all edges cost 1: `bfs` is enough.

## Nim shape

`src/nimcs/algo/dijkstra.nim`: `dijkstra(g, source): Result[PathTree, GraphError]`. The heap is a local `HeapQueue[(int, int)]` of (distance, vertex); unreachable vertices have distance none. Distances are `int`: keep sums below `high(int)`.

```nim
import std/options
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/dijkstra

let g = buildGraph(4, @[edge(0, 1, 10), edge(0, 2, 3), edge(2, 1, 4), edge(1, 3, 2)], gkDirected).value
let tree = dijkstra(g, 0).value
assert tree.distance(1) == some(7)
assert tree.pathTo(3) == some(@[0, 2, 1, 3])
```

## Laws and invariants

- With non-negative weights distances equal Bellman-Ford's, reported paths weigh exactly the distance (GRAPH-DIJKSTRA-01).
- A negative arc gives `geNegativeWeight`; a bad source `geVertexOutOfRange` (GRAPH-DIJKSTRA-02).

## Complexity

- Time: O((V + E) log V). Space: O(V + E) worst case for the lazy heap.

## Pitfalls

Running it on negative weights and trusting the answer: the algorithm terminates and returns plausible-looking wrong distances.

```nim bad
let tree = dijkstra(g, 0)    # a graph with a -2 arc: unchecked, silently wrong in a language that does not refuse
```

The fix is what the module does: scan the arcs first and return `err(PathTree, geNegativeWeight)`, so the caller must choose `bellman_ford`.

## Related

- `bellman_ford.nim`, `floyd_warshall.nim`, `bfs.nim`, `graph.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `61811291625a13a9` Algorithms for Competitive Programming
- `a8882bbba7213b23` Algorithms Notes for Professionals
- `63ad3e14455a34af` Competitive Programmer's Handbook
- `e8a751ae9f8ed52b` Learning Algorithm
- `6f359b1814ec2eeb` Princeton University Algorithms, Part 2
