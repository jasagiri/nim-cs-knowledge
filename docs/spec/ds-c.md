# Specification: persistent and functional data structures (DS), part c

Each row is a law or an externally visible behaviour; each ID has at least one tagged test in `tests/test_ds_<concept>.nim`.

| ID | Concept | Statement |
|---|---|---|
| DS-BTREE-01 | b_tree | Given a degree below 2, when creating a tree, then none; otherwise an empty tree of that degree |
| DS-BTREE-02 | b_tree | Given any keys and a degree, when inserted, then iteration is the sorted distinct keys |
| DS-BTREE-03 | b_tree | Given a tree, when asking contains, then it is true exactly for the inserted keys |
| DS-BTREE-04 | b_tree | Given random inserts, when checking the structure, then node sizes, child counts and leaf depth hold at every step |
| DS-BTREE-05 | b_tree | Given a member, when inserting it again, then the result equals the tree and shares its size |
| DS-BTREE-06 | b_tree | Given a tree, when inserting a new key, then the old version is unchanged |
| DS-BTREE-07 | b_tree | Given ascending and descending inserts, when counting levels, then the height stays logarithmic |
| DS-BTREE-08 | b_tree | Given n keys and degree t, when reading the height h, then n is at least 2 * t^(h-1) - 1 |
| DS-BTREE-09 | b_tree | Given a key type ordered only by `<`, when inserting equivalent keys, then one stays |
| DS-FENWICK-01 | fenwick_tree | Given any array, when asking every prefix sum, then it equals the sum of that prefix |
| DS-FENWICK-02 | fenwick_tree | Given any array and range, when asking rangeSum, then it equals the sum of the slice |
| DS-FENWICK-03 | fenwick_tree | Given random point updates, when compared with a plain array, then every prefix sum and element agrees |
| DS-FENWICK-04 | fenwick_tree | Given a tree, when updating, then the old tree is unchanged |
| DS-FENWICK-05 | fenwick_tree | Given a list of updates, when applied with addAll or one by one, then the trees agree |
| DS-FENWICK-06 | fenwick_tree | Given indices or sizes out of range, when using the tree, then the result is none |
| DS-FENWICK-07 | fenwick_tree | Given the same array, when queried through a Fenwick tree and a segment tree, then all range sums agree |
| DS-FENWICK-08 | fenwick_tree | Given an array, when rebuilt from its values, then the tree answers the same queries |
| DS-SPARSETABLE-01 | sparse_table | Given any array and range, when querying min, max, gcd or keep-left, then it equals the fold over the slice |
| DS-SPARSETABLE-02 | sparse_table | Given an empty or out-of-range range, when querying, then the result is none |
| DS-SPARSETABLE-03 | sparse_table | Given n elements, when building, then there are floor(log2 n) + 1 levels |
| DS-SPARSETABLE-04 | sparse_table | Given a non-idempotent operation, when the two windows overlap, then the answer is wrong |
| DS-SPARSETABLE-05 | sparse_table | Given the same array, when queried through a sparse table and a segment tree, then all range minima agree |
| DS-SPARSETABLE-06 | sparse_table | Given a table, when querying the same range repeatedly, then the answer never changes |
| DS-SPARSETABLE-07 | sparse_table | Given five thousand elements, when querying many ranges, then every answer equals the fold |
| DS-BITVECTOR-01 | bit_vector | Given a negative size or an out-of-range index, when constructing, then none; otherwise len is the size |
| DS-BITVECTOR-02 | bit_vector | Given a size and indices, when testing every position, then exactly the given indices are set |
| DS-BITVECTOR-03 | bit_vector | Given any vector, when setting or clearing a bit twice, then the second result equals the first |
| DS-BITVECTOR-04 | bit_vector | Given a vector, when setting or clearing a bit, then the old vector is unchanged |
| DS-BITVECTOR-05 | bit_vector | Given any vector, when counting, then count is the number of distinct indices |
| DS-BITVECTOR-06 | bit_vector | Given any vector, when asking rank at every position, then it is the number of members below it |
| DS-BITVECTOR-07 | bit_vector | Given any vector, when selecting the k-th member, then it is the k-th smallest index and rank inverts it |
| DS-BITVECTOR-08 | bit_vector | Given vectors of one size, when combining, then union, intersection and difference match the set operations |
| DS-BITVECTOR-09 | bit_vector | Given vectors, when taking union or intersection, then each is commutative, associative and idempotent |
| DS-BITVECTOR-10 | bit_vector | Given a vector, when complementing, then it flips exactly the bits below len and twice gives the original |
| DS-BITVECTOR-11 | bit_vector | Given vectors of different sizes, when combining, then the result is none |
| DS-BITVECTOR-12 | bit_vector | Given sizes at word boundaries, when setting the last bit, then no bit past the end appears |
