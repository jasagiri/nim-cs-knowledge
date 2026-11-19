# Bellman-Ford

## Intent

Relax every arc, repeat V - 1 times: after k rounds every shortest path of at most k arcs is correct. If a further round still improves some distance, a negative cycle is reachable from the source, and following predecessors from the improved vertex lands inside it.

## Use when / avoid when

- Use when: weights may be negative, or you must detect a negative cycle (arbitrage, contradictory constraints).
- Avoid when: all weights are non-negative; `dijkstra` is much faster.
- Avoid when: you need every pair; `floyd_warshall`.

## Nim shape

`src/nimcs/algo/bellman_ford.nim`: `bellmanFord(g, source): Result[PathTree, BellmanFordError]`. The error is an object variant: `bfBadSource` or `bfNegativeCycle` with the `cycle` (listed once around, smallest vertex first). An undirected edge of negative weight is a negative cycle of two arcs.

```nim
import std/options
import nimcs/fp/result
import nimcs/algo/graph
import nimcs/algo/bellman_ford

let ok1 = buildGraph(3, @[edge(0, 1, 4), edge(0, 2, 5), edge(2, 1, -3)], gkDirected).value
assert bellmanFord(ok1, 0).value.distance(1) == some(2)

let bad = buildGraph(3, @[edge(0, 1, 1), edge(1, 2, -2), edge(2, 1, 1)], gkDirected).value
let failure = bellmanFord(bad, 0).error
assert failure.kind == bfNegativeCycle
assert failure.cycle == @[1, 2]
```

## Laws and invariants

- Without a negative cycle, distances equal Floyd-Warshall's row; negative arcs are handled (GRAPH-BELLMAN-01).
- A reported cycle is real and negative; some source reports a cycle exactly when Floyd-Warshall fails; a cycle that cannot be reached from the source is ignored (GRAPH-BELLMAN-02).

## Complexity

- Time: O(V * E) worst case (stops early when a round changes nothing). Space: O(V).

## Pitfalls

Returning distances after V - 1 rounds without the extra round: with a negative cycle the numbers are just wherever the loop stopped.

```nim bad
for pass in 1 ..< n:        # n - 1 rounds, no check for a further improvement
  relaxAll()
result = ok(distances)      # wrong when a negative cycle is reachable
```

The fix is the n-th round: if anything still improves, return the cycle as an error.

## Related

- `dijkstra.nim`, `floyd_warshall.nim`, `graph.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `61811291625a13a9` Algorithms for Competitive Programming
- `a8882bbba7213b23` Algorithms Notes for Professionals
- `63ad3e14455a34af` Competitive Programmer's Handbook
- `e8a751ae9f8ed52b` Learning Algorithm
