# Spec: algorithms A (sorting, searching, graphs)

Laws and observable behaviour of `src/nimcs/algo/` modules insertion_sort, merge_sort, quick_sort,
heap_sort, radix_sort, binary_search, graph, bfs, dfs, topo_sort, scc, dijkstra, bellman_ford,
floyd_warshall, kruskal, prim. Tests: `tests/test_algo_<module>.nim`.

| ID | Concept | Statement |
|---|---|---|
| SORT-INSERT-01 | insertion_sort | For any integer sequence, `insertionSort(xs) == sorted(xs)` (sorted and a permutation of the input). |
| SORT-INSERT-02 | insertion_sort | With a descending comparator the result is the input sorted descending. |
| SORT-INSERT-03 | insertion_sort | Idempotent: `insertionSort(insertionSort(xs)) == insertionSort(xs)`. |
| SORT-INSERT-04 | insertion_sort | An empty or one-element input comes back unchanged. |
| SORT-INSERT-05 | insertion_sort | Stable: elements equal under the comparator keep their input order. |
| SORT-MERGE-01 | merge_sort | For any integer sequence, `mergeSort(xs) == sorted(xs)`. |
| SORT-MERGE-02 | merge_sort | With a descending comparator the result is the input sorted descending. |
| SORT-MERGE-03 | merge_sort | Idempotent: `mergeSort(mergeSort(xs)) == mergeSort(xs)`. |
| SORT-MERGE-04 | merge_sort | An empty or one-element input comes back unchanged. |
| SORT-MERGE-05 | merge_sort | Stable: elements equal under the comparator keep their input order. |
| SORT-QUICK-01 | quick_sort | For any integer sequence, `quickSort(xs) == sorted(xs)`. |
| SORT-QUICK-02 | quick_sort | With a descending comparator the result is the input sorted descending. |
| SORT-QUICK-03 | quick_sort | Idempotent: `quickSort(quickSort(xs)) == quickSort(xs)`. |
| SORT-QUICK-04 | quick_sort | An empty or one-element input comes back unchanged. |
| SORT-QUICK-05 | quick_sort | Stable: elements equal under the comparator keep their input order. |
| SORT-HEAP-01 | heap_sort | For any integer sequence, `heapSort(xs) == sorted(xs)`. |
| SORT-HEAP-02 | heap_sort | With a descending comparator the result is the input sorted descending. |
| SORT-HEAP-03 | heap_sort | Idempotent: `heapSort(heapSort(xs)) == heapSort(xs)`. |
| SORT-HEAP-04 | heap_sort | An empty or one-element input comes back unchanged. |
| SORT-HEAP-05 | heap_sort | Sorting records by key yields ascending keys and loses no record (stability is not promised). |
| SORT-RADIX-01 | radix_sort | For non-negative integers, `radixSort(xs)` is `ok(sorted(xs))`, including values needing several bytes and the empty input. |
| SORT-RADIX-02 | radix_sort | A negative element makes `radixSort` return the error `skNegative`. |
| SORT-RADIX-03 | radix_sort | `countingSortBy` is a stable sort by key; `countingSort` equals `sorted` for integers below the bound. |
| SORT-RADIX-04 | radix_sort | `countingSort` reports `skOutOfRange` for a key at or above the bound, `skNegative` for a negative key, `skBadBound` for a bound below 1. |
| SORT-RADIX-05 | radix_sort | Idempotent: radix sorting a radix-sorted sequence changes nothing. |
| SORT-RADIX-06 | radix_sort | A bound above `maxCountingBound` (2^24) is refused with `skBoundTooLarge` before anything is allocated. |
| SEARCH-LOWER-01 | binary_search | `lowerBound(xs, x)` is the index before which all elements are less than `x` and from which none is; works with a custom comparator and on an empty input. |
| SEARCH-UPPER-01 | binary_search | `upperBound(xs, x)` is the index before which all elements are at most `x` and from which all are greater; works with a custom comparator and on an empty input. |
| SEARCH-RANGE-01 | binary_search | `upperBound - lowerBound` equals the number of copies of `x`. |
| SEARCH-FIND-01 | binary_search | `binarySearch` returns the first index holding `x` exactly when `x` is present, else none. |
| SEARCH-PARTITION-01 | binary_search | For a monotone predicate, `partitionPoint` is the first index where it holds (the length when it never does). |
| SEARCH-FIRST-01 | binary_search | For a monotone predicate on an integer range, `firstTrue` is the least index satisfying it, the upper end when none does, and the lower end for an empty range, for any bounds in the whole `int` range (no overflow). |
| GRAPH-BUILD-01 | graph | The same edges in any order build equal graphs. |
| GRAPH-BUILD-02 | graph | A negative vertex count gives `geNegativeOrder`; an endpoint outside 0 ..< n gives `geVertexOutOfRange`. |
| GRAPH-BUILD-03 | graph | `buildGraph(n, g.edges, kind) == g`, and `g.edges` lists as many edges as were given. |
| GRAPH-BUILD-04 | graph | Each neighbour list ascends by (target, weight). |
| GRAPH-BUILD-05 | graph | An undirected graph has every arc together with its reverse; a directed edge has only its own direction. |
| GRAPH-TRANSPOSE-01 | graph | `transpose` reverses every arc, transposing twice gives the graph back, an undirected graph is its own transpose. |
| GRAPH-PATH-01 | graph | `PathTree.pathTo(v)` runs from the source to `v` along existing arcs with length `distance + 1`, and is none exactly when `v` is unreachable or not a vertex. |
| GRAPH-BFS-01 | bfs | BFS distances equal the fewest edges from the source (checked against a relaxation oracle); a bad source gives `geVertexOutOfRange`; parents follow neighbour order. |
| GRAPH-DFS-01 | dfs | `dfs` returns pre- and postorder of exactly the vertices reachable from the start, start first in preorder and last in postorder; neighbour order decides ties; a bad start is an error; a 100 000-vertex path does not overflow the stack. |
| GRAPH-DFS-02 | dfs | `dfsForest` lists every vertex exactly once in each order. |
| GRAPH-DFS-03 | dfs | On an acyclic graph, for every arc the head finishes (postorder) before the tail. |
| GRAPH-TOPO-01 | topo_sort | On an acyclic graph the order is a permutation of the vertices with every arc pointing forward. |
| GRAPH-TOPO-02 | topo_sort | On any directed graph the result is a valid order or an error holding a real cycle (every consecutive arc and the closing arc exist), starting at its smallest vertex; self-loops and undirected edges are cycles. |
| GRAPH-TOPO-03 | topo_sort | The order is the lexicographically smallest valid one. |
| GRAPH-TOPO-04 | topo_sort | `topoSort` fails exactly when some strongly connected component has several vertices or a vertex has a self-loop. |
| GRAPH-SCC-01 | scc | The components partition the vertices; each is ascending and components ascend by smallest vertex. |
| GRAPH-SCC-02 | scc | Two vertices share a component exactly when each reaches the other. |
| GRAPH-DIJKSTRA-01 | dijkstra | With non-negative weights distances equal Bellman-Ford's, `pathTo` weights equal the distance, and a small example gives the cheaper detour. |
| GRAPH-DIJKSTRA-02 | dijkstra | A negative arc gives `geNegativeWeight`; a bad source gives `geVertexOutOfRange`. |
| GRAPH-BELLMAN-01 | bellman_ford | Without a negative cycle, distances equal Floyd-Warshall's row for the source; negative arcs are handled. |
| GRAPH-BELLMAN-02 | bellman_ford | A reported negative cycle is real (arcs exist) and its cheapest weight is negative; from each source a cycle is reported exactly when a negative closed walk is reachable from it (checked against a separate Floyd-Warshall oracle); a cycle unreachable from the source is ignored. |
| GRAPH-FLOYD-01 | floyd_warshall | With non-negative weights every row equals Dijkstra from that source; unreachable pairs and non-vertices have no distance. |
| GRAPH-FLOYD-02 | floyd_warshall | The result is an error exactly when some source sees a negative cycle; a negative self-loop names its vertex. |
| GRAPH-FLOYD-03 | floyd_warshall | `pathBetween(u, v)` follows existing arcs with the distance as its weight, and is none exactly when `v` is unreachable from `u`. |
| GRAPH-KRUSKAL-01 | kruskal | On an undirected graph the result is a spanning forest: edges from the graph, acyclic, same connectivity, totals consistent. |
| GRAPH-KRUSKAL-02 | kruskal | The total weight equals the cheapest spanning forest found by brute force. |
| GRAPH-KRUSKAL-03 | kruskal | Kruskal and Prim give the same total weight, component count and edge count. |
| GRAPH-KRUSKAL-04 | kruskal | A directed graph is refused with `geNotUndirected`. |
| GRAPH-PRIM-01 | prim | On an undirected graph the result is a spanning forest (edges from the graph, acyclic, same connectivity, totals consistent), one tree per component. |
| GRAPH-PRIM-02 | prim | A directed graph is refused with `geNotUndirected`. |
