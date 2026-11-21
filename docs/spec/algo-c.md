# Specification: algorithms (ALGO), part C

Prefixes: `CODING-` coding, `GRAPH-` flow and matching, `TECH-` search techniques (two pointers, windows, prefix sums), `ANALYSIS-` analysis of algorithms, `SORT-` and `ELEMSORT-` sorting.
Every ID has at least one test tagged `# SPEC: <ID>` in `tests/test_algo_<module>.nim`.

| ID | Concept | Statement |
|---|---|---|
| CODING-HUFFMAN-01 | huffman | The code built from (symbol, frequency) pairs does not depend on the order of the pairs; the tie-break (weight, then smallest symbol, first taken = 0) gives the hand-derived words for a:5 b:2 c:1 d:1. |
| CODING-HUFFMAN-02 | huffman | No code word begins another, and no word is repeated. |
| CODING-HUFFMAN-03 | huffman | `decode(encode(t)) == t` for every text built into the code; the empty text round-trips. |
| CODING-HUFFMAN-04 | huffman | The weighted length equals the cost found by repeatedly merging the two smallest weights; for two or more symbols the words fill the code space (Kraft sum 1) and a more frequent symbol never has a longer word. |
| CODING-HUFFMAN-05 | huffman | An empty list, a frequency below one, a repeated symbol and a total weight that overflows each give their own error. |
| CODING-HUFFMAN-06 | huffman | Encoding a character with no code word gives `heUnknownSymbol`. |
| CODING-HUFFMAN-07 | huffman | Decoding a character other than 0 or 1, or bits that stop inside a code word, gives `heBadBits`. |
| CODING-HUFFMAN-08 | huffman | A single symbol gets the word "0"; only zero bits decode. |
| GRAPH-MAXFLOW-01 | max_flow | The flow value equals the textbook value on a known network and, on small random directed and undirected graphs, the smallest capacity over all vertex sets holding the source and not the sink. |
| GRAPH-MAXFLOW-02 | max_flow | The returned cut holds the source and not the sink, consists of arcs leaving `sourceSide`, and its capacity equals the flow value. |
| GRAPH-MAXFLOW-03 | max_flow | Each ordered pair carries positive flow at most its capacity, every vertex other than source and sink keeps what it receives, and the sink receives exactly the value. |
| GRAPH-MAXFLOW-04 | max_flow | A source or sink outside the graph, equal source and sink, and a negative capacity each give their own error. |
| GRAPH-MAXFLOW-05 | max_flow | When the sink cannot be reached the value is 0, there are no flows, and `sourceSide` is the set the source reaches. |
| GRAPH-MAXFLOW-06 | max_flow | Parallel arcs add their capacities; an opposite arc does not raise the flow; an undirected edge carries its capacity in either direction. |
| GRAPH-MATCHING-01 | max_flow | The size of the matching equals that of an exhaustive search on small bipartite graphs. |
| GRAPH-MATCHING-02 | max_flow | Every matched pair was offered, left vertices are ascending and distinct, and right vertices are distinct. |
| GRAPH-MATCHING-03 | max_flow | A negative side size gives `feNegativeCount` and a pair outside the sides gives `feVertexOutOfRange`; no vertices and no pairs give an empty matching. |
| GRAPH-MATCHING-04 | max_flow | A case where taking the first free partner blocks a vertex still gets the perfect matching. |
| TECH-TWOPTR-01 | two_pointers | `pairWithSum` on an ascending sequence equals a brute-force search taking the smallest first index and, for it, the largest second index. |
| TECH-TWOPTR-02 | two_pointers | No pair, an empty sequence and a single element give `peNoPair`. |
| TECH-TWOPTR-03 | two_pointers | A sequence that is not ascending gives `peNotSorted`. |
| TECH-WINDOW-01 | two_pointers | For non-negative numbers `longestWindowAtMost` equals a brute-force search (longest, then earliest) and its sum is within the bound; with no qualifying element it is the empty window at 0. |
| TECH-WINDOW-02 | two_pointers | Each entry of `windowSums` equals the re-added sum of its window of the given size; a size above the length gives no sums. |
| TECH-WINDOW-03 | two_pointers | A negative element gives `weNegativeElement`. |
| TECH-WINDOW-04 | two_pointers | A negative bound gives `weNegativeBound`. |
| TECH-WINDOW-05 | two_pointers | A window size below one gives `weBadSize`. |
| ANALYSIS-ASYMP-01 | analysis | Comparing every pair of n distinct numbers makes exactly n(n-1)/2 comparisons; an early duplicate stops the count. |
| ANALYSIS-ASYMP-02 | analysis | Binary search makes at most floor(log2 n) + 1 probes for any key; 1023 items need at most 10. |
| ANALYSIS-ASYMP-03 | analysis | `isBigOOn` and `isBigOmegaOn` accept a right constant and refute a wrong one over the checked range. |
| ANALYSIS-ASYMP-04 | analysis | `ceilLog2(n)` is the k with 2^(k-1) < n <= 2^k for n >= 1 and none below 1. |
| ANALYSIS-ASYMP-05 | analysis | Linear search takes position plus one steps, or the length when the key is absent. |
| ANALYSIS-AMORT-01 | analysis | n appends to a doubling array cost at most 3n in total; the costs of five appends are 1, 2, 3, 1, 5. |
| ANALYSIS-AMORT-02 | analysis | n appends to an array that grows by one cost exactly n(n+1)/2, more than 3n from n = 6. |
| ANALYSIS-AMORT-03 | analysis | With the potential 2 * size - capacity every amortized cost of a doubling append is at most 3, the potential is never negative and the amortized costs add up to at least the real total. |
| ANALYSIS-AMORT-04 | analysis | n increments of a binary counter flip exactly 2n - popcount(n) bits; an increment yields the next number and leaves the old counter unchanged; an all-ones counter flips every bit. |
| SORT-COUNTING-01 | counting_sort | For integers inside lo .. hi, `countingSortRange` equals `sorted`, also for negative keys, a wider range, a single-value range and the empty input. |
| SORT-COUNTING-02 | counting_sort | `countingSortByRange` is stable: records with equal keys keep their input order. |
| SORT-COUNTING-03 | counting_sort | A key below or above the range gives `ceOutOfRange`. |
| SORT-COUNTING-04 | counting_sort | A reversed range gives `ceBadRange`; a range wider than `maxCountingSpan` gives `ceRangeTooLarge` (without overflow, also for the full `int` range); the widest allowed range is accepted. |
| SORT-COUNTING-05 | counting_sort | Entry i of `keyHistogram` is the number of keys equal to lo + i, and the entries add up to the number of keys. |
| SORT-COUNTING-06 | counting_sort | `countingSortAuto` equals `sorted` when the spread of the data is small, refuses a larger spread with `ceRangeTooLarge`, and maps the empty input to an empty result. |
| SORT-COUNTING-07 | counting_sort | Idempotent: sorting the result again changes nothing. |
| SORT-COUNTING-08 | counting_sort | For non-negative integers `countingSortAuto` and `radixSort` give the same result. |
| ELEMSORT-SELECT-01 | elementary_sorts | For any integer sequence, `selectionSort(xs) == sorted(xs)`. |
| ELEMSORT-SELECT-02 | elementary_sorts | With a descending comparator the result is the input sorted descending. |
| ELEMSORT-SELECT-03 | elementary_sorts | Selection sort makes at most len - 1 swaps, and none on a sorted input. |
| ELEMSORT-SELECT-04 | elementary_sorts | Selection sort is not stable: on a pinned witness equal keys change order, while `insertionSort` keeps it. |
| ELEMSORT-SELECT-05 | elementary_sorts | Idempotent; an empty or one-element input comes back unchanged. |
| ELEMSORT-SHELL-01 | elementary_sorts | For any integer sequence, `shellSort(xs) == sorted(xs)`, ascending and with a descending comparator, also on an input that uses five gaps. |
| ELEMSORT-SHELL-02 | elementary_sorts | `shellSortWithGaps` sorts correctly for any strictly descending list of positive gaps ending in 1. |
| ELEMSORT-SHELL-03 | elementary_sorts | Shellsort is not stable: equal keys change order on a three-record witness with gaps 2, 1 and on fifteen records with the default gaps, while `insertionSort` keeps it. |
| ELEMSORT-SHELL-04 | elementary_sorts | The default gaps are Knuth's (each 3h + 1), strictly descending, below n div 3 except the final 1, and end in 1 for every n. |
| ELEMSORT-SHELL-05 | elementary_sorts | An empty gap list, a gap below one, a list that is not strictly descending and a list not ending in 1 each give their own `GapError`. |
| ELEMSORT-SHELL-06 | elementary_sorts | Idempotent; an empty or one-element input comes back unchanged. |
| TECH-PREFIX-01 | prefix_sum | The prefix table has one entry more than the data, starts at 0 and adds each element. |
| TECH-PREFIX-02 | prefix_sum | `rangeSum(l, r)` equals the sum added element by element, is additive over a split point, and is 0 for an empty range. |
| TECH-PREFIX-03 | prefix_sum | A range outside the data gives `reOutOfBounds` and a reversed range gives `reReversed`. |
| TECH-PREFIX-04 | prefix_sum | `fromDifferences(differences(xs)) == xs` and `differences(fromDifferences(d)) == d`. |
| TECH-PREFIX-05 | prefix_sum | `applyRangeAdds` equals adding each range element by element; overlapping deltas add and an empty range changes nothing. |
| TECH-PREFIX-06 | prefix_sum | An update outside 0 .. n, a reversed update and a negative size give `reOutOfBounds` or `reReversed`. |
| TECH-PREFIX-07 | prefix_sum | `rectSum` equals the sum added cell by cell, for the whole grid, one cell and an empty rectangle. |
| TECH-PREFIX-08 | prefix_sum | A rectangle outside the grid, or reversed on either axis, gives `reOutOfBounds` or `reReversed`. |
| TECH-PREFIX-09 | prefix_sum | Rows of different lengths give `reRagged`; an empty grid and a grid of empty rows are accepted. |
