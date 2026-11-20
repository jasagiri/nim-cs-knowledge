# Specification: persistent and functional data structures (DS)

Each row is a law or an externally visible behaviour; each ID has at least one tagged test in `tests/test_ds_<concept>.nim`.

| ID | Concept | Statement |
|---|---|---|
| DS-CONSLIST-01 | cons_list | Given any list, when consing x, then head is x and tail is the original |
| DS-CONSLIST-02 | cons_list | Given the empty list, when asking head and tail, then head is none and tail is empty |
| DS-CONSLIST-03 | cons_list | Given any list, when reversed twice, then it equals the original |
| DS-CONSLIST-04 | cons_list | Given lists a, b, c, when appending, then append is associative with the empty list as identity |
| DS-CONSLIST-05 | cons_list | Given a list, when appending b, then the result shares all of b |
| DS-CONSLIST-06 | cons_list | Given a list, when updating a copy by cons, then the old list is unchanged |
| DS-CONSLIST-07 | cons_list | Given any list, when folding or mapping, then results agree with the seq versions |
| DS-CONSLIST-08 | cons_list | Given a list of three million nodes, when it goes out of scope, then dropping it does not overflow the stack |
| DS-CONSLIST-09 | cons_list | Given a list, when another list is consed onto it, then its first cell counts as shared |
| DS-BANKERSQUEUE-01 | bankers_queue | Given any items, when pushed in order and popped until empty, then they leave in the same order |
| DS-BANKERSQUEUE-02 | bankers_queue | Given the empty queue, when peeking or popping, then peek is none and pop stays empty |
| DS-BANKERSQUEUE-03 | bankers_queue | Given a queue, when pushing or popping, then the old version is unchanged |
| DS-BANKERSQUEUE-04 | bankers_queue | Given a random sequence of pushes and pops, when compared with a seq model, then contents and length agree at every step |
| DS-BANKERSQUEUE-05 | bankers_queue | Given a large queue, when filled and drained, then all elements come out in order |
| DS-DEQUE-01 | deque | Given any items, when pushed at the back, then toSeq is the items in order |
| DS-DEQUE-02 | deque | Given any items, when pushed at the front, then toSeq is the items reversed |
| DS-DEQUE-03 | deque | Given random operations at both ends, when compared with a seq model, then contents, ends and length agree |
| DS-DEQUE-04 | deque | Given a deque, when pushing or popping, then the old version is unchanged |
| DS-DEQUE-05 | deque | Given the empty deque, when peeking or popping, then ends are none and pops stay empty |
| DS-DEQUE-06 | deque | Given many pushes at one end, when popped from the other end, then order is preserved |
| DS-LEFTISTHEAP-01 | leftist_heap | Given any items, when inserted and drained by deleteMin, then they come out sorted |
| DS-LEFTISTHEAP-02 | leftist_heap | Given two heaps, when merged in either order, then both hold exactly the union of their elements |
| DS-LEFTISTHEAP-03 | leftist_heap | Given any items, when asking findMin, then it is the minimum and deleteMin removes one copy of it |
| DS-LEFTISTHEAP-04 | leftist_heap | Given a heap, when inserting or deleting, then the old version is unchanged |
| DS-LEFTISTHEAP-05 | leftist_heap | Given the empty heap, when asking for the minimum or deleting, then findMin is none and it stays empty |
| DS-LEFTISTHEAP-06 | leftist_heap | Given random inserts and deleteMins, when checking the structure, then its invariants hold at every step |
| DS-LEFTISTHEAP-07 | leftist_heap | Given one million descending inserts, when the heap is used and dropped, then nothing overflows the stack |
| DS-LEFTISTHEAP-08 | leftist_heap | Given a wrapper module that orders its elements with its own `<`, when the wrapper is used from another module, then the heap uses that `<` if the wrapper is not generic or the `<` is exported, and compiling fails with a type mismatch if a generic wrapper keeps it private |
| DS-PAIRINGHEAP-01 | pairing_heap | Given any items, when inserted and drained by deleteMin, then they come out sorted |
| DS-PAIRINGHEAP-02 | pairing_heap | Given two heaps, when merged in either order, then both hold exactly the union of their elements |
| DS-PAIRINGHEAP-03 | pairing_heap | Given any items, when asking findMin, then it is the minimum and deleteMin removes one copy of it |
| DS-PAIRINGHEAP-04 | pairing_heap | Given a heap, when inserting or deleting, then the old version is unchanged |
| DS-PAIRINGHEAP-05 | pairing_heap | Given the empty heap, when asking for the minimum or deleting, then findMin is none and it stays empty |
| DS-PAIRINGHEAP-06 | pairing_heap | Given 300000 ascending inserts, when the heap is used and dropped, then nothing overflows the stack |
| DS-BINOMIALHEAP-01 | binomial_heap | Given any items, when inserted and drained by deleteMin, then they come out sorted |
| DS-BINOMIALHEAP-02 | binomial_heap | Given two heaps, when merged in either order, then both hold exactly the union of their elements |
| DS-BINOMIALHEAP-03 | binomial_heap | Given any items, when asking findMin, then it is the minimum and deleteMin removes one copy of it |
| DS-BINOMIALHEAP-04 | binomial_heap | Given a heap, when inserting or deleting, then the old version is unchanged |
| DS-BINOMIALHEAP-05 | binomial_heap | Given the empty heap, when asking for the minimum or deleting, then findMin is none and it stays empty |
| DS-BINOMIALHEAP-06 | binomial_heap | Given random inserts and deleteMins, when checking the structure, then its invariants hold at every step |
| DS-BINOMIALHEAP-07 | binomial_heap | Given a heap of n elements, when listing tree ranks, then they are the set bits of n |
| DS-RBTREE-01 | rb_tree | Given any keys, when inserted into a set, then toSeq is the sorted distinct keys |
| DS-RBTREE-02 | rb_tree | Given pairs, when put into a map, then get returns the last value of each key and none otherwise |
| DS-RBTREE-03 | rb_tree | Given any insertion order, when the tree is built, then the red-black invariants hold after every insert |
| DS-RBTREE-04 | rb_tree | Given sorted input, when inserted, then the height stays logarithmic |
| DS-RBTREE-05 | rb_tree | Given a map, when putting a key, then the old map is unchanged |
| DS-RBTREE-06 | rb_tree | Given the empty map, when looking up, then get is none and the map is empty |
| DS-RBTREE-07 | rb_tree | Given a set, when including a present key, then the set is equal in content and size |
| DS-RBTREE-08 | rb_tree | Given a tree where a grandchild breaks the search order, when checking invariants, then they do not hold |
| DS-SKEWLIST-01 | skew_list | Given any items, when built by consing, then toSeq returns them in order and get(i) is the i-th |
| DS-SKEWLIST-02 | skew_list | Given any list, when consing then taking the tail, then head and tail round-trip |
| DS-SKEWLIST-03 | skew_list | Given any list and index, when updated, then only that index changes and the original is unchanged |
| DS-SKEWLIST-04 | skew_list | Given any sequence of cons and tail, when running, then the skew-binary invariants hold and the spine stays short |
| DS-SKEWLIST-05 | skew_list | Given the empty list, when asking head, tail or get, then head and get are none and tail is empty |
| DS-SKEWLIST-06 | skew_list | Given 1000 items, when looking up every index, then each lookup finds its element |
| DS-PVECTOR-01 | pvector | Given any items, when pushed, then toSeq and get(i) return them in order |
| DS-PVECTOR-02 | pvector | Given a vector and an index, when updated, then only that index changes and the original is unchanged |
| DS-PVECTOR-03 | pvector | Given a vector, when pushing, then the old version keeps its length and contents |
| DS-PVECTOR-04 | pvector | Given sizes around the 32-way boundaries, when pushed, then every element is reachable and depth grows by one level per factor 32 |
| DS-PVECTOR-05 | pvector | Given the empty vector, when reading or updating, then get and updated are none |
| DS-PVECTOR-06 | pvector | Given a vector of 33000 elements with four trie levels, when updated at random indices, then only those indices change and the original is unchanged |
| DS-HAMT-01 | hamt | Given pairs, when put, then get returns the last value of each key and none for absent keys |
| DS-HAMT-02 | hamt | Given a map and a key, when removing it, then the key is gone, the others stay and the size drops |
| DS-HAMT-03 | hamt | Given a map, when putting or removing, then the old map is unchanged |
| DS-HAMT-04 | hamt | Given keys inserted in any order, when listing with toSortedSeq, then the result is sorted by key and independent of insertion order |
| DS-HAMT-05 | hamt | Given keys with colliding hashes, when put, read and removed, then every key stays distinct and reachable |
| DS-HAMT-06 | hamt | Given the empty map, when reading or removing, then get is none and remove changes nothing |
| DS-HAMT-07 | hamt | Given string keys, when put and read, then lookup agrees with a table model |
| DS-TRIE-01 | trie | Given any words, when inserted, then contains is true exactly for the inserted words |
| DS-TRIE-02 | trie | Given any words and prefix, when listing keysWithPrefix, then the result is the sorted distinct words with that prefix |
| DS-TRIE-03 | trie | Given a word already present, when inserted again, then the trie is unchanged in size and content |
| DS-TRIE-04 | trie | Given a trie, when inserting a word, then the old trie is unchanged |
| DS-TRIE-05 | trie | Given words where one is a prefix of another, when queried, then the prefix is a word only if inserted |
| DS-TRIE-06 | trie | Given the empty trie or the empty word, when queried, then results are empty or exact |
| DS-ZIPPER-01 | zipper | Given a list zipper, when moving right then left, then the zipper is back at the same place |
| DS-ZIPPER-02 | zipper | Given a list zipper, when setting the focus, then only the focused element changes and the original is unchanged |
| DS-ZIPPER-03 | zipper | Given the ends of a list, when moving beyond them, then the move is none; an empty list has no zipper |
| DS-ZIPPER-04 | zipper | Given a tree zipper, when going down and back up, then the tree is rebuilt equal to the original |
| DS-ZIPPER-05 | zipper | Given a path, when modifying at its end and rebuilding, then exactly the value at that place changes and the original tree is unchanged |
| DS-ZIPPER-06 | zipper | Given a leaf or the root, when moving down past a leaf or up past the root, then the move is none |
| DS-ZIPPER-07 | zipper | Given a focused subtree, when replacing it, then the rebuilt tree contains the replacement in that place |
| DS-UNIONFIND-01 | union_find | Given any unions, when asking same, then it agrees with a naive reference |
| DS-UNIONFIND-02 | union_find | Given any unions, when asking same, then it is reflexive, symmetric and transitive |
| DS-UNIONFIND-03 | union_find | Given a union, when repeated, then the relation and the component count are unchanged |
| DS-UNIONFIND-04 | union_find | Given a structure, when uniting, then the old version still answers as before |
| DS-UNIONFIND-05 | union_find | Given chained unions, when measuring a root path, then union by rank keeps it within log2 of the element count |
| DS-UNIONFIND-06 | union_find | Given a path, when compressing, then the representative is the same and the path is shorter |
| DS-UNIONFIND-07 | union_find | Given an unknown element, when finding, then it is its own set and the structure is unchanged |
| DS-UNIONFIND-08 | union_find | Given random unions over many elements, when measuring every root path, then it is at most floor(log2 of the element count) |
| DS-SEGTREE-01 | segment_tree | Given any array and range, when querying a sum, then it equals the sum of that slice |
| DS-SEGTREE-02 | segment_tree | Given a non-commutative monoid, when querying a range, then elements are combined in index order |
| DS-SEGTREE-03 | segment_tree | Given a tree and an index, when updating, then queries see the new value and the old tree is unchanged |
| DS-SEGTREE-04 | segment_tree | Given an empty range, when querying, then the monoid identity is returned; invalid ranges give none |
| DS-SEGTREE-05 | segment_tree | Given the empty array, when building and asking, then total is the identity and every access is none or empty |
| DS-SEGTREE-06 | segment_tree | Given any array, when asking total, then it equals the query over the whole range |
| DS-BLOOM-01 | bloom_filter | Given any added keys, when asking mightContain, then every added key is found (no false negatives) |
| DS-BLOOM-02 | bloom_filter | Given a filter, when adding a key twice, then the bit array equals adding it once |
| DS-BLOOM-03 | bloom_filter | Given a filter, when adding a key, then the old filter is unchanged |
| DS-BLOOM-04 | bloom_filter | Given two filters of equal shape, when merged, then the result has the same bits as one filter holding all keys, and merge is commutative |
| DS-BLOOM-05 | bloom_filter | Given invalid sizes or mismatched shapes, when constructing or merging, then an error value says why |
| DS-BLOOM-06 | bloom_filter | Given a well sized filter, when probing absent keys, then false positives are rare |
| DS-BLOOM-07 | bloom_filter | Given any bit count including non powers of two, when adding one key, then it sets exactly min(hashes, bits) distinct bits |
| DS-MERKLE-01 | merkle_tree | Given any bytes, when put and read back, then get returns the bytes and the name is their hash |
| DS-MERKLE-02 | merkle_tree | Given a store, when the same bytes are put twice, then one copy is kept and the old store is unchanged |
| DS-MERKLE-03 | merkle_tree | Given a missing name or a stored copy that no longer hashes to its name, when reading, then get says missing or corrupt |
| DS-MERKLE-04 | merkle_tree | Given any blocks, when proving each leaf, then the proof verifies against the root |
| DS-MERKLE-05 | merkle_tree | Given a valid proof, when the block, index, root or path is wrong, then verification fails |
| DS-MERKLE-06 | merkle_tree | Given blocks, when any one leaf changes or one is added or dropped, then the root changes |
| DS-MERKLE-07 | merkle_tree | Given a tree, when a leaf is updated or a block appended, then the result equals a tree built from scratch and the old tree is unchanged |
| DS-MERKLE-08 | merkle_tree | Given n leaves, when one is updated or one appended, then only the nodes on one path are rebuilt and the rest is shared |
| DS-MERKLE-09 | merkle_tree | Given no blocks or one block, when building, proving and updating, then the results are defined |
| DS-MERKLE-10 | merkle_tree | Given an inner node's two digests, when they are offered as one leaf block, then the root differs from the real tree's |
| DS-MERKLE-11 | merkle_tree | Given a hash with collisions, when a colliding block is substituted, then get and the root accept it |
| DS-MERKLE-12 | merkle_tree | Given blocks with a repeated last block, when building, then the root differs from the shorter list |
| DS-MERKLE-13 | merkle_tree | Given no hash procedure or an empty name, when building a hasher, then an error says why |
