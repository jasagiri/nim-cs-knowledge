# Specification: persistent and functional data structures (DS), part d

Each row is a law or an externally visible behaviour; each ID has at least one tagged test in `tests/test_ds_<concept>.nim`.

| ID | Concept | Statement |
|---|---|---|
| DS-TREAP-01 | treap | Given any keys, when inserted, then contains agrees with a set and toSeq is the sorted distinct keys |
| DS-TREAP-02 | treap | Given a treap, when inserting a present key or deleting an absent one, then nothing changes |
| DS-TREAP-03 | treap | Given a treap, when deleting a key, then it is gone and the others stay |
| DS-TREAP-04 | treap | Given two insertion orders of the same keys and one seed, when comparing, then the shapes are identical |
| DS-TREAP-05 | treap | Given the same keys and different seeds, when comparing, then the contents agree though the shapes may differ |
| DS-TREAP-06 | treap | Given a treap and a key, when splitting, then the parts hold the smaller and larger keys and found tells presence |
| DS-TREAP-07 | treap | Given the two halves of a split, when merged, then the original key set is back |
| DS-TREAP-08 | treap | Given overlapping key ranges or different seeds, when merging, then an error is returned |
| DS-TREAP-09 | treap | Given a treap, when inserting or deleting, then the old version is unchanged |
| DS-TREAP-10 | treap | Given random inserts and deletes, when checking the structure, then its invariants hold at every step |
| DS-TREAP-11 | treap | Given the empty treap, when asking min, max, contains or deleting, then it answers none, false and stays empty |
| DS-TREAP-12 | treap | Given ascending keys inserted in order, when measuring the height, then it stays logarithmic rather than linear |
| DS-TREAP-13 | treap | Given string keys, when inserted, then they come out sorted and the shape does not depend on the insertion order |
| DS-SPLAYTREE-01 | splay_tree | Given any keys, when inserted, then toSeq is the sorted distinct keys and lookup finds exactly those |
| DS-SPLAYTREE-02 | splay_tree | Given a tree and a present key, when looking it up, then the returned tree has that key at the root |
| DS-SPLAYTREE-03 | splay_tree | Given an absent key, when looking it up, then found is false and the last node visited is at the root |
| DS-SPLAYTREE-04 | splay_tree | Given a tree, when inserting a key, then it is at the root and a present key leaves the key set unchanged |
| DS-SPLAYTREE-05 | splay_tree | Given a tree, when deleting a key, then it is gone, the rest stays, and an absent key changes nothing |
| DS-SPLAYTREE-06 | splay_tree | Given a tree, when looking up, inserting or deleting, then the old version is unchanged |
| DS-SPLAYTREE-07 | splay_tree | Given a lookup, when the same key is asked again on the returned tree, then it is at depth 0 |
| DS-SPLAYTREE-08 | splay_tree | Given one old version, when its deepest key is looked up repeatedly without threading the tree, then every lookup is as deep as the first |
| DS-SPLAYTREE-09 | splay_tree | Given a long run of lookups threaded forward, when the keys are random, then every tree stays valid and the key set never changes |
| DS-SPLAYTREE-10 | splay_tree | Given the empty tree, when asking anything, then it is empty and deleting leaves it empty |
| DS-SPLAYTREE-11 | splay_tree | Given a thousand ascending inserts, when everything is looked up in order, then the work stays far below quadratic |
| DS-SPLAYTREE-12 | splay_tree | Given a chain of one million nodes from ascending inserts, when it is used and dropped, then nothing overflows the stack |
| DS-KDTREE-01 | kd_tree | Given any points, when the tree is built, then it holds exactly those points and its invariants hold |
| DS-KDTREE-02 | kd_tree | Given points and a query, when asking for the nearest, then it equals the brute-force answer with the smallest point on ties |
| DS-KDTREE-03 | kd_tree | Given points and a rectangle, when querying, then the answer is the brute-force filter in lexicographic order |
| DS-KDTREE-04 | kd_tree | Given the empty tree, when asking, then nearest is none and every rectangle is empty |
| DS-KDTREE-05 | kd_tree | Given a NaN, infinite or oversized coordinate, when building, then badCoordinate is returned |
| DS-KDTREE-06 | kd_tree | Given the same points in any input order, when building, then nearest and rectangle answers are identical |
| DS-KDTREE-07 | kd_tree | Given duplicate points, when building and querying, then each copy is kept and counted |
| DS-KDTREE-08 | kd_tree | Given a large grid, when building, then the height stays logarithmic |
| DS-KDTREE-09 | kd_tree | Given a tree, when queried, then it is not changed (the value is immutable) |
| DS-SUFFIXTRIE-01 | suffix_trie | Given any text and pattern, when counting, then the trie agrees with a naive scan including overlaps |
| DS-SUFFIXTRIE-02 | suffix_trie | Given any text, when counting distinct substrings, then it equals the size of the set of all substrings |
| DS-SUFFIXTRIE-03 | suffix_trie | Given any text, when asking for the longest repeat, then it is the longest substring seen twice, smallest on ties |
| DS-SUFFIXTRIE-04 | suffix_trie | Given a known text, when querying, then the textbook answers come out |
| DS-SUFFIXTRIE-05 | suffix_trie | Given the empty text, when querying, then nothing is found and the trie is empty |
| DS-SUFFIXTRIE-06 | suffix_trie | Given a text over the maximum length, when building, then textTooLong is returned and the maximum itself is accepted |
| DS-SUFFIXTRIE-07 | suffix_trie | Given any text, when asking for the shortest absent string, then it is absent and every shorter string is present |
| DS-SUFFIXTRIE-08 | suffix_trie | Given one text, when building twice, then the answers are identical |
