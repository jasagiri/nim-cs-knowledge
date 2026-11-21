# Specification: algorithms (STR, GEO, CYCLE, GRAPH, LCA, MITM, EXTSORT, APPROX), part D

Prefixes: `STR-` strings, `GEO-` geometry, `CYCLE-` cycle detection, `GRAPH-` graph algorithms, `LCA-` lowest common ancestor, `MITM-` meet in the middle, `EXTSORT-` external sorting, `APPROX-` approximation algorithms.
Every ID has at least one test tagged `# SPEC: <ID>` in `tests/test_algo_<module>.nim`.

| ID | Concept | Statement |
|---|---|---|
| STR-AHOCORASICK-01 | aho_corasick | `findAll` returns the hand-worked matches for the he/she/his/hers set, and for any text and pattern set exactly the (start, pattern index) pairs of the naive search. |
| STR-AHOCORASICK-02 | aho_corasick | Overlapping and nested patterns are all reported; matches ascend by (start, pattern index), lie inside the text and spell their pattern. |
| STR-AHOCORASICK-03 | aho_corasick | With a single pattern the match starts equal `kmpFindAll`. |
| STR-AHOCORASICK-04 | aho_corasick | `countAll` gives for each pattern the number of its matches; `patternCount` is the number of patterns. |
| STR-AHOCORASICK-05 | aho_corasick | An empty pattern makes `buildAho` fail with `aeEmptyPattern`; an empty pattern list builds. |
| STR-AHOCORASICK-06 | aho_corasick | Duplicate patterns are each reported, under their own index, at the same offsets. |
| STR-AHOCORASICK-07 | aho_corasick | Searching twice with one automaton, or with a rebuilt one, gives the same matches. |
| GEO-CONVEXHULL-01 | convex_hull | The hull of a square with interior and edge points is its four corners; for any small point set the hull vertices are exactly the extreme points found by a cubic triangle-membership oracle. |
| GEO-CONVEXHULL-02 | convex_hull | A hull of three or more vertices starts at the smallest (x, y) point and every consecutive turn is strictly counter-clockwise. |
| GEO-CONVEXHULL-03 | convex_hull | Every input point is on or left of every hull edge, and every hull vertex is an input point. |
| GEO-CONVEXHULL-04 | convex_hull | No points, one point or repeated copies of one point, and collinear points give respectively no vertices, that point, and the two endpoints. |
| GEO-CONVEXHULL-05 | convex_hull | The hull of the hull, of the reversed input and of the input doubled equals the hull. |
| GEO-CONVEXHULL-06 | convex_hull | `cross` is positive for a left turn, negative for a right turn and zero for collinear points, and is exact at coordinates of `MaxCoord`. |
| GEO-CONVEXHULL-07 | convex_hull | Coordinates of absolute value up to `MaxCoord` are accepted; one beyond fails with `heCoordinateTooLarge`. |
| CYCLE-FLOYD-01 | cycle_detection | `floydRho` returns the hand-worked tail, cycle length and entry, and for any function table and start equals the first-seen-step oracle. |
| CYCLE-FLOYD-02 | cycle_detection | The entry is reached after exactly `tail` steps, returns to itself after `cycle` steps and not after fewer, and `tail + cycle <= n`. |
| CYCLE-FLOYD-03 | cycle_detection | `iterateFunction` equals stepping one at a time for small counts and handles a count of 10^12; negative steps give none. |
| CYCLE-FLOYD-04 | cycle_detection | A permutation has tail 0 from every start. |
| CYCLE-FLOYD-05 | cycle_detection | An image or start outside 0 ..< n, or an empty table, gives none. |
| CYCLE-GRAPH-01 | cycle_detection | `findCycle` on a directed graph returns a real cycle (every consecutive arc exists, no repeated vertex) starting at its smallest vertex, or none. |
| CYCLE-GRAPH-02 | cycle_detection | A directed graph has a cycle exactly when `topoSort` fails. |
| CYCLE-GRAPH-03 | cycle_detection | A self-loop is the cycle of one vertex, the hand-worked loop is found, a DAG has none, and repeated calls agree. |
| CYCLE-GRAPH-04 | cycle_detection | An undirected graph is refused with `ceNotDirected`. |
| GRAPH-EULER-01 | eulerian_path | The hand-worked trails come back, and any trail found walks every edge exactly once (consecutive vertices match the edge multiset, length is edges + 1). |
| GRAPH-EULER-02 | eulerian_path | A trail is found exactly when brute-force backtracking finds one; degree violations and disconnected edges give none. |
| GRAPH-EULER-03 | eulerian_path | `eulerianCircuit` is a closed trail of every edge and exists exactly when brute force finds a closed trail; an open trail only gives none. |
| GRAPH-EULER-04 | eulerian_path | Parallel edges and self-loops are each walked once, in both graph kinds. |
| GRAPH-EULER-05 | eulerian_path | A graph without edges has the empty trail and the empty circuit. |
| GRAPH-EULER-06 | eulerian_path | Asking twice gives the same trail. |
| LCA-QUERY-01 | lca | `lca` returns the hand-drawn answers and for every pair of every generated tree equals the walk-up oracle. |
| LCA-QUERY-02 | lca | `lca` is symmetric, `lca(u, u) = u`, the root with anything is the root, and a parent with its child is the parent. |
| LCA-DEPTH-01 | lca | `depth` equals the number of steps to the root, the root has depth 0 and `size` is the vertex count. |
| LCA-ANCESTOR-01 | lca | `kthAncestor(v, k)` equals k single parent steps, and is none past the root or for negative k. |
| LCA-DISTANCE-01 | lca | `distance` equals depth(u) + depth(v) - 2 depth(lca), is symmetric and is 0 for equal vertices. |
| LCA-BUILD-01 | lca | `buildLca` fails with the matching error for an empty array, a parent out of range, no root, several roots and a cycle among parents; a root other than vertex 0 is accepted. |
| LCA-BUILD-02 | lca | A vertex outside the tree is answered with none by every query. |
| LCA-BUILD-03 | lca | A tree whose root is not vertex 0 and whose parents have larger indices than their children is queried correctly. |
| MITM-COUNT-01 | meet_in_middle | `countSubsetSum` gives the hand-worked counts (equal items are distinct choices, the empty subset counts) and for any small instance equals brute force over all subsets. |
| MITM-COUNT-02 | meet_in_middle | Reordering the items does not change the count. |
| MITM-EXISTS-01 | meet_in_middle | `subsetSumExists` is true exactly when the brute-force count is positive. |
| MITM-CLOSEST-01 | meet_in_middle | `closestSubsetSum` equals brute force, a tie going to the smaller sum. |
| MITM-CLOSEST-02 | meet_in_middle | Between two reachable sums the nearer comes back, a reachable target comes back exactly, and no items give 0. |
| MITM-LIMIT-01 | meet_in_middle | More than `MaxItems` items, an item beyond `MaxItemValue` and a target beyond `MaxTarget` each fail with their own error; the limits themselves pass. |
| MITM-SCALE-01 | meet_in_middle | Thirty equal items give the binomial counts C(30, k) without enumerating 2^30 subsets. |
| EXTSORT-SORT-01 | external_sort | `externalSort` gives the hand-worked list and I/O cost, and for any data, memory and fan-in its items equal the in-memory sort. |
| EXTSORT-SORT-02 | external_sort | Sorting the sorted output again leaves the items unchanged. |
| EXTSORT-SORT-03 | external_sort | Empty data costs nothing, memory holding all data needs no merge pass, and memory < 1 or fan-in < 2 fail with `eeBadMemory` or `eeBadFanIn`. |
| EXTSORT-RUNS-01 | external_sort | `formRuns` gives ceil(n / memory) runs, each sorted, non-empty and at most `memory` long. |
| EXTSORT-RUNS-02 | external_sort | The runs together hold exactly the input items. |
| EXTSORT-MERGE-01 | external_sort | `mergeRuns` of sorted runs is the sorted concatenation; no runs or empty runs are accepted. |
| EXTSORT-COST-01 | external_sort | The counted merge passes equal the least p with fanIn^p >= runs and `expectedMergePasses`; reads and writes both equal n * (1 + passes). |
| EXTSORT-COST-02 | external_sort | For the same data a larger fan-in never needs more merge passes; `expectedMergePasses` is 0 for at most one run and exact on 1000 and 1001 runs at fan-in 10. |
| APPROX-VC-01 | approximation | Every edge of an undirected graph has an end in the returned cover. |
| APPROX-VC-02 | approximation | The matching is vertex-disjoint with every edge in the graph, and the cover has at most twice its size. |
| APPROX-VC-03 | approximation | For graphs of up to 8 vertices the cover is no smaller than, and at most twice, the exact minimum found by trying every subset. |
| APPROX-VC-04 | approximation | On a path of four vertices the ratio 2 is reached (4 against 2); on a star the cover has 2 against 1. |
| APPROX-VC-05 | approximation | A graph without edges has an empty cover; a self-loop puts its vertex in the cover. |
| APPROX-VC-06 | approximation | A directed graph is refused with `geNotUndirected`. |
| APPROX-VC-07 | approximation | `isVertexCover` accepts only sets touching every edge and ignores vertices outside the graph. |
| APPROX-VC-08 | approximation | The same graph gives the same cover and matching. |
