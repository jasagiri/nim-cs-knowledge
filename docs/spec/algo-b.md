# Spec: algorithms, part B (dynamic programming, strings, numbers, search techniques)

Prefixes: `DP-` dynamic programming, `STR-` strings, `NUM-` numbers, `TECH-` search techniques.
Every ID has at least one test tagged `# SPEC: <ID>` in `tests/test_algo_<module>.nim`.

| ID | Concept | Statement |
|---|---|---|
| DP-MEMO-01 | memoization | The bottom-up Fibonacci routine returns the known values (F(0)=0, F(1)=1, F(50)=12586269025, F(92)=7540113804746346429). |
| DP-MEMO-02 | memoization | For every n in 0..92 the top-down Fibonacci with a fresh memo equals the bottom-up value. |
| DP-MEMO-03 | memoization | `put` returns a new memo that knows the key; `get` finds it; the memo `put` was called on is unchanged; putting an existing key replaces its value without growing `len`. |
| DP-MEMO-04 | memoization | Fibonacci outside 0..92, and a grid with rows < 1, cols < 1 or rows + cols > 64, give `none`. |
| DP-MEMO-05 | memoization | The number of right/down grid paths computed top-down and bottom-up both equal the binomial coefficient C(rows+cols-2, rows-1). |
| DP-MEMO-06 | memoization | Calling again with the memo a call returned gives the same value and the same memo size (idempotent); a smaller sub-problem already in the memo does not grow it. |
| DP-MEMO-07 | memoization | Computing fib(n) with a fresh memo stores exactly the sub-problems 2..n, each with its correct value. |
| DP-LCS-01 | lcs | `lcsLength` returns the hand-worked lengths (empty input 0, "abcbdab"/"bdcaba" 4, disjoint alphabets 0), also for non-character sequences. |
| DP-LCS-02 | lcs | `lcs(a, b)` is a subsequence of both `a` and `b`. |
| DP-LCS-03 | lcs | `lcs(a, b).len == lcsLength(a, b)` and that length equals the best over all subsequences of `a` found by brute force. |
| DP-LCS-04 | lcs | `lcsLength` is symmetric and at most the shorter length. |
| DP-LCS-05 | lcs | `lcs(a, a) == a`, and repeated calls return the same subsequence. |
| DP-EDIT-01 | edit_distance | `editDistance` returns the hand-worked values (kitten/sitting 3, flaw/lawn 2, equal strings 0, against the empty string the length). |
| DP-EDIT-02 | edit_distance | d(a, a) = 0, and d(a, b) = 0 only when a = b. |
| DP-EDIT-03 | edit_distance | d(a, b) = d(b, a). |
| DP-EDIT-04 | edit_distance | d(a, c) <= d(a, b) + d(b, c); d(a, b) <= max(len a, len b); d(a, b) >= abs(len a - len b). |
| DP-EDIT-05 | edit_distance | The cost of `editScript(a, b)` equals `editDistance(a, b)`, and the script is the same on every call. |
| DP-EDIT-06 | edit_distance | `applyScript(a, editScript(a, b))` is `some(b)`; a script that names a character `a` does not have at that place, or leaves input unread, gives `none`. |
| DP-KNAP-01 | knapsack | A classic instance gives the hand-worked value, items and weight; capacity 0 or no items gives value 0. |
| DP-KNAP-02 | knapsack | The packing value equals the best over all subsets (brute force, up to 8 items). |
| DP-KNAP-03 | knapsack | The chosen indices are strictly ascending and valid, their weights fit the capacity and equal `weight`, and their values add up to `value`. |
| DP-KNAP-04 | knapsack | A negative capacity, weight or value gives `none` (also from the `item` smart constructor). |
| DP-KNAP-05 | knapsack | The result is the same on every call, and one more unit of capacity never lowers the value. |
| DP-KNAP-06 | knapsack | A capacity for which `(items + 1) * (capacity + 1)` would exceed `maxTableCells`, including `high(int)`, gives `none`; a small capacity is computed. |
| DP-LIS-01 | lis | Hand-worked lengths: [10,9,2,5,3,7,101,18] 4, constant sequence 1, empty 0, decreasing 1, increasing n. |
| DP-LIS-02 | lis | The O(n log n) length equals the O(n^2) table's length on any sequence. |
| DP-LIS-03 | lis | The returned subsequence is strictly increasing and its indices are ascending positions in the input holding those values. |
| DP-LIS-04 | lis | When several longest subsequences exist, the same one is returned on every call. |
| STR-KMP-01 | kmp | `kmpFailure(p)[i]` is the length of the longest proper border of `p[0..i]`. |
| STR-KMP-02 | kmp | `kmpFindAll` returns the same positions as the naive search on any text and pattern. |
| STR-KMP-03 | kmp | Overlapping occurrences are all reported, ascending. |
| STR-KMP-04 | kmp | An empty pattern occurs at every offset 0..text.len. |
| STR-ZALGO-01 | z_algorithm | `zArray(s)[i]` is the length of the common prefix of `s` and `s[i..]`. |
| STR-ZALGO-02 | z_algorithm | `zArray(s)[0] == s.len`, and the Z-array of the empty string is empty. |
| STR-ZALGO-03 | z_algorithm | `zFindAll` returns the same positions as the naive search, including patterns with characters that also occur in the text. |
| STR-ZALGO-04 | z_algorithm | An empty pattern occurs at every offset 0..text.len. |
| STR-RK-01 | rabin_karp | Each rolling window hash equals a fresh `hashOf` of that window. |
| STR-RK-02 | rabin_karp | With a realistic modulus `rkFindAll` equals the naive search. |
| STR-RK-03 | rabin_karp | With a tiny modulus (many collisions) the candidates are a superset of the results, yet the results equal the naive search: no false positives. |
| STR-RK-04 | rabin_karp | An empty pattern occurs at every offset; a pattern longer than the text occurs nowhere. |
| STR-RK-05 | rabin_karp | A modulus outside 2..2^31-1, and a base below 2 or not below the modulus, give `none`. |
| STR-SA-01 | suffix_array | The suffix array is a permutation of 0..n-1 whose suffixes are in strictly ascending order, and equals the order obtained by sorting the suffix strings. |
| STR-SA-02 | suffix_array | Hand-worked arrays: banana gives [5,3,1,0,4,2]; the empty string gives an empty array. |
| STR-SA-03 | suffix_array | `lcpArray[i]` is the shared prefix length of the suffixes at `sa[i-1]` and `sa[i]`, and 0 for i = 0. |
| STR-SA-04 | suffix_array | `lcpArray` gives `none` for an array that is not the suffix array of the string (wrong length, repeat, out of range, wrong order). |
| STR-SA-05 | suffix_array | `countDistinctSubstrings` equals the size of the set of all substrings. |
| STR-SA-06 | suffix_array | `isSuffixArrayOf` runs in O(n) and agrees with comparing the suffix strings on every candidate array (valid or not); validation does not make `lcpArray` quadratic on repetitive input. |
| STR-MERGE3-01 | three_way_merge | `mergeKeyed`: a key unchanged, changed on one side only, or changed the same way on both sides (modification, deletion, addition) takes that value and the merge is clean. |
| STR-MERGE3-02 | three_way_merge | A key changed differently on both sides (delete against modify and two different additions included) is returned as a `KeyConflict` value with its base, ours and theirs versions (`none` for absent), in ascending key order; the keys settled cleanly are kept in `resolved`; nothing is raised. |
| STR-MERGE3-03 | three_way_merge | The conflicting keys are exactly the keys whose ours and theirs versions both differ from the base and from each other. |
| STR-MERGE3-04 | three_way_merge | merge(b, b, b) = b; merge(b, x, b) = x; merge(b, b, x) = x; merge(b, x, x) = x, all clean. |
| STR-MERGE3-05 | three_way_merge | Swapping ours and theirs gives the same clean map, or the same conflicts with ours and theirs exchanged (`swapSides`). |
| STR-MERGE3-06 | three_way_merge | In a clean keyed merge every key either side changed carries that side's version, a deletion removing the key. |
| STR-MERGE3-07 | three_way_merge | `merge3` on hand-worked line edits: edits in different places merge, the same change on both sides is clean, delete against modify, two insertions into one gap and edits on neighbouring lines are conflict hunks. |
| STR-MERGE3-08 | three_way_merge | merge3(b, b, b) is the single stable chunk b (none for an empty b); merge3(b, x, b), merge3(b, b, x) and merge3(b, x, x) are clean and read as x. |
| STR-MERGE3-09 | three_way_merge | Swapping ours and theirs gives the same chunks with clean sides and every conflict's ours and theirs exchanged (`swapSides`). |
| STR-MERGE3-10 | three_way_merge | When edits use unique lines and the merge is clean, the merged lines are exactly the lines both sides kept plus every line either side inserted, none that either side deleted, and each side's remaining lines keep their order. |
| STR-MERGE3-11 | three_way_merge | No two stable chunks are adjacent or empty, and in every conflict hunk ours, theirs and base are pairwise different. |
| STR-MERGE3-12 | three_way_merge | `render` writes a clean merge as its lines, each ended by a newline, and fences a conflict as `<<<<<<< ours`, `||||||| base`, `=======`, `>>>>>>> theirs` with the labels replaceable; `toLines` and `mergeLines` and `conflictCount` agree with it. |
| NUM-NT-01 | number_theory | `gcd` is non-negative, symmetric, divides both arguments, leaves coprime quotients, `gcd(0,0)=0`, and gives `none` for `low(int)`. |
| NUM-NT-02 | number_theory | `gcd * lcm == abs(a * b)`; `lcm` with 0 is 0; overflow and `low(int)` give `none`. |
| NUM-NT-03 | number_theory | `extGcd` returns g, x, y with `a*x + b*y == g` and g equal to `gcd` (Bezout), for negative and zero arguments too. |
| NUM-NT-04 | number_theory | `powMod` equals repeated multiplication mod m, handles negative bases, Fermat's little theorem holds, and a negative exponent gives `none`. |
| NUM-NT-05 | number_theory | `modInverse` returns x in 0..m-1 with `a*x ≡ 1 (mod m)` exactly when gcd(a, m) = 1, else `none`. |
| NUM-NT-06 | number_theory | A modulus outside 1..3037000499 gives `none`; `residue` maps negative numbers into 0..m-1. |
| NUM-SIEVE-01 | sieve | `sieveFlags(n)[i]` is true exactly when trial division says `i` is prime, for all 0 <= i <= n. |
| NUM-SIEVE-02 | sieve | The prime counts match the prime-counting function (25 up to 100, 168 up to 1000, 9592 up to 100000). |
| NUM-SIEVE-03 | sieve | A limit below 2 gives an empty list; any list is strictly ascending, within the limit and prime. |
| NUM-FIBM-01 | fib_matrix | `fibMatrix(n)` equals the iterative value for every n in 0..92. |
| NUM-FIBM-02 | fib_matrix | `fibMod(n, m)` equals the iterative value taken mod m. |
| NUM-FIBM-03 | fib_matrix | `fibMatrix` gives `none` outside 0..92, and F(n) = F(n-1) + F(n-2) inside. |
| NUM-FIBM-04 | fib_matrix | F(n) mod 10 repeats with period 60 for huge n; n < 0 or a modulus outside 1..3037000499 gives `none`. |
| NUM-SIEVE-04 | sieve | A limit above `maxSieveLimit` (also `high(int)`) gives `none`; a negative limit gives an empty list; `sieveFlags` and `primesUpTo` return `Option`. |
| TECH-BT-GEN-01 | backtracking | `backtrack` returns the accepted states in pre-order depth-first, left-to-right order. |
| TECH-BT-GEN-02 | backtracking | The same arguments give the same list; a tree with no accepted state gives an empty list. |
| TECH-BT-GEN-03 | backtracking | `firstSolution` is the head of the full list, and `none` when there is no solution. |
| TECH-BT-PERM-01 | backtracking | `permutations(n)` has n! distinct entries in lexicographic order (one empty entry for n = 0). |
| TECH-BT-PERM-02 | backtracking | Every permutation is a rearrangement of 0..n-1. |
| TECH-BT-PERM-03 | backtracking | n < 0 or n above the exported limit gives `none`. |
| TECH-BT-COMB-01 | backtracking | `combinations(n, k)` has C(n, k) ascending k-subsets of 0..n-1 in lexicographic order. |
| TECH-BT-COMB-02 | backtracking | Negative arguments or n above the exported limit give `none`; k > n gives an empty list. |
| TECH-BT-QUEENS-01 | backtracking | The number of n-queens solutions is 1, 1, 0, 0, 2, 10, 4, 40, 92 for n = 0..8. |
| TECH-BT-QUEENS-02 | backtracking | Every solution has no two queens in a shared column or diagonal, solutions are distinct and ordered, and n < 0 or n above the exported limit gives `none`. |
| TECH-GREEDY-01 | greedy | Half-open intervals that only touch do not overlap; the schedule of a worked example is the expected one; no intervals give an empty schedule. |
| TECH-GREEDY-02 | greedy | The chosen intervals are pairwise disjoint and maximal: every other interval overlaps a chosen one. |
| TECH-GREEDY-03 | greedy | The schedule size equals the optimum over all subsets (the exchange argument checked by brute force), and the schedule is the same on every call. |
| TECH-GREEDY-04 | greedy | An empty or reversed range gives `none` from `interval`; `Interval` has private fields, so no empty or reversed interval can be built any other way. |
| TECH-GREEDY-05 | greedy | Fractional knapsack on the classic lots 60/10, 100/20, 120/30 with capacity 50 takes lots 0 and 1 whole and 20 units of lot 2, for a value of exactly 240; zero-weight lots are always taken. |
| TECH-GREEDY-06 | greedy | The packed weight fits the capacity, at most one lot is cut (0 < taken < weight), every taken lot has at least the value-per-weight of every untaken one, and the capacity is full whenever a positive-weight lot was left out. |
| TECH-GREEDY-07 | greedy | The fractional value is at least the best whole-item (0/1) value, and the result is the same on every call. |
| TECH-GREEDY-08 | greedy | A negative capacity, weight or value gives `none`. |
| TECH-DC-MAXSUB-01 | divide_conquer | Kadane's scan returns the hand-worked sum and slice. |
| TECH-DC-MAXSUB-02 | divide_conquer | The divide-and-conquer version returns the hand-worked sum. |
| TECH-DC-MAXSUB-03 | divide_conquer | On any non-empty array both methods and brute force give the same sum, and each returned slice is in range and adds up to its sum. |
| TECH-DC-MAXSUB-04 | divide_conquer | Empty input gives `none` from both. |
| TECH-DC-MASTER-01 | divide_conquer | Classic recurrences (merge sort, binary search, Karatsuba, Strassen) land in their textbook master-theorem case. |
| TECH-DC-MASTER-02 | divide_conquer | The case agrees with comparing a to b^d with exact powers, never moves toward the root as a grows, and a huge d does not overflow. |
| TECH-DC-MASTER-03 | divide_conquer | a < 1, b < 2 or d < 0 gives `none`. |
