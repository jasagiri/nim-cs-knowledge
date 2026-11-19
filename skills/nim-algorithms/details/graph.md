# Immutable graph

## Intent

A graph is a value: a vertex count and, for each vertex, its list of outgoing arcs. Building it validates the edges once and puts every neighbour list in a canonical order, so the same edges in any order give equal graphs and every algorithm that walks neighbours in order is deterministic.

## Use when / avoid when

- Use when: you feed any graph algorithm in this package (`bfs`, `dfs`, `dijkstra`, ...).
- Use `PathTree` (distance and parent per vertex) and `SpanningForest` as the shared result types.
- Avoid when: the graph changes constantly (each change here means a rebuild); keep an edge list and rebuild, or use a mutable structure at the edge of your program.
- Avoid when: vertices are not small integers; map your keys to `0 ..< n` first and keep the table outside.

## Nim shape

`src/nimcs/algo/graph.nim`. Vertices are `0 ..< n`. `buildGraph(order, edges, kind)` returns `Result[Graph, GraphError]`; `kind` is `gkDirected` or `gkUndirected` (an undirected edge is stored as two arcs, a self-loop once; parallel edges are kept). Read with `neighbors`, `edges`, `hasArc`, `vertexCount`, `transpose`.

```nim
import nimcs/fp/result
import nimcs/algo/graph

let built = buildGraph(3, @[edge(0, 1, 5), edge(1, 2, 2)], gkUndirected)
assert built.isOk
let g = built.value
assert g.hasArc(1, 0)
assert g.neighbors(1)[0] == Arc(target: 0, weight: 5)
assert buildGraph(2, @[edge(0, 2)], gkDirected) == err(Graph, geVertexOutOfRange)
```

## Laws and invariants

- The same edges in any order build equal graphs (GRAPH-BUILD-01).
- A negative vertex count or an endpoint outside `0 ..< n` is an error value (GRAPH-BUILD-02).
- `buildGraph(n, g.edges, kind) == g` (GRAPH-BUILD-03).
- Each neighbour list ascends by (target, weight) (GRAPH-BUILD-04).
- An undirected graph has every arc with its reverse; a directed edge only its own direction (GRAPH-BUILD-05).
- `transpose` reverses every arc and is an involution (GRAPH-TRANSPOSE-01).
- `PathTree.pathTo(v)` runs from the source to `v` over real arcs, none when unreachable (GRAPH-PATH-01).

## Complexity

- Build: O(V + E log E) for the sorting of neighbour lists. `neighbors`: O(1). `hasArc`: O(degree). `edges`, `transpose`: O(V + E log E). Space: O(V + E).

## Pitfalls

Passing a vertex that is not in `0 ..< vertexCount` to `neighbors`: that is a caller bug and raises an `IndexDefect`. Algorithms that take a source check it and return `geVertexOutOfRange`; check the vertex yourself before calling `neighbors` directly.

```nim bad
let arcs = g.neighbors(userSuppliedVertex)   # IndexDefect when out of range
```

The fix is `if g.inRange(v): ... else: ...`, or going through an algorithm that returns a `Result`.

## Related

- `bfs.nim`, `dfs.nim`, `topo_sort.nim`, `scc.nim`, `dijkstra.nim`, `bellman_ford.nim`, `floyd_warshall.nim`, `kruskal.nim`, `prim.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `6f31dd50eef1beba` Algorithmic Thinking
- `b6deea26499dcff1` Algorithms
- `29ca95172575b79a` Algorithms and Data Structures
- `c1b93dc13846e70a` Algorithms Course Materials
- `473f0313d72c526b` Algorithms, 4th Edition
- `42a1cb32a5e35bad` An Open Guide to Data Structures and Algorithms
- `b609569e40e49e47` Analysis of Algorithms (CSE 373)
- `63ad3e14455a34af` Competitive Programmer's Handbook
