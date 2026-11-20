# Specification: data structures, basic and balanced (DS), part b

Each row is a law or an externally visible behaviour; each ID has at least one tagged test in `tests/test_ds_<concept>.nim`.

| ID | Concept | Statement |
|---|---|---|
| DS-HASHTABLE-01 | hash_table | Given a table, when a key is put twice, then get returns the latest value and len counts the key once |
| DS-HASHTABLE-02 | hash_table | Given a table, when asking for an absent key, then get is none and contains is false |
| DS-HASHTABLE-03 | hash_table | Given a table, when deleting a key, then it is gone, the others stay, and a missing key changes nothing |
| DS-HASHTABLE-04 | hash_table | Given random puts and deletes, when compared with std/tables, then both hold the same entries |
| DS-HASHTABLE-05 | hash_table | Given a table, when putting or deleting, then the old version is unchanged |
| DS-HASHTABLE-06 | hash_table | Given random puts and deletes, when checking the layout, then the probe-run invariants hold at every step |
| DS-HASHTABLE-07 | hash_table | Given a thousand keys, when they are all put, then every key is found and the table grew |
| DS-HASHTABLE-08 | hash_table | Given the same entries in any insertion order, when listing sortedPairs, then the lists are equal |
| DS-HASHTABLE-09 | hash_table | Given a repeated key, when built with fromPairs, then the last pair wins |
| DS-HASHTABLE-10 | hash_table | Given keys that all hash to two home slots, when deleting any key, then the rest are still found |
| DS-BST-01 | bst | Given any items, when inserted, then in-order traversal is the sorted distinct items |
| DS-BST-02 | bst | Given any items, when asking contains, then it is true exactly for the inserted items |
| DS-BST-03 | bst | Given a tree, when inserting an item already present, then the tree is the same |
| DS-BST-04 | bst | Given any items and one of them, when deleting it, then it is gone, the rest remain and order holds |
| DS-BST-05 | bst | Given a node with two children, when deleting it, then the in-order successor takes its place |
| DS-BST-06 | bst | Given the tree 4 2 6 1 3 5 7, when traversing, then the three orders match the textbook lists |
| DS-BST-07 | bst | Given any items, when re-inserting the pre-order list, then the same shape is rebuilt |
| DS-BST-08 | bst | Given a tree, when inserting or deleting, then the old version is unchanged |
| DS-BST-09 | bst | Given the empty tree, when querying, then smallest and largest are none and delete keeps it empty |
| DS-BST-10 | bst | Given sorted inserts, when measuring the height, then it equals the item count (the tree is a list) |
| DS-BST-11 | bst | Given random inserts and deletes, when checking the structure, then the order invariant holds at every step |
| DS-BST-12 | bst | Given one million ascending items (a chain), when the tree is dropped, then nothing overflows the stack |
| DS-BST-13 | bst | Given items that are not strictly ascending, when asking for a chain, then none; given ascending items, then it equals repeated insert |
| DS-BINARYHEAP-01 | binary_heap | Given any items, when pushed and drained by pop, then they come out sorted |
| DS-BINARYHEAP-02 | binary_heap | Given any items, when built with heapify, then the heap order holds and toSortedSeq is the sorted items |
| DS-BINARYHEAP-03 | binary_heap | Given any items, when asking peek, then it is the minimum and pop removes one copy of it |
| DS-BINARYHEAP-04 | binary_heap | Given a heap, when pushing or popping, then the old version is unchanged |
| DS-BINARYHEAP-05 | binary_heap | Given the empty heap, when peeking or popping, then peek is none and it stays empty |
| DS-BINARYHEAP-06 | binary_heap | Given random pushes and pops, when checking the layout, then no item is smaller than its parent at every step |
| DS-BINARYHEAP-07 | binary_heap | Given any items, when compared with std/heapqueue, then both drain in the same order |
| DS-BINARYHEAP-08 | binary_heap | Given items with equal keys, when sorted through the heap, then the keys are in order |
| DS-STACKQUEUE-01 | stack_queue | Given any items, when pushed and popped, then they come back in reverse order |
| DS-STACKQUEUE-02 | stack_queue | Given any stack and an item, when pushing then popping, then the original stack returns |
| DS-STACKQUEUE-03 | stack_queue | Given any items, when enqueued and dequeued, then they come back in the same order |
| DS-STACKQUEUE-04 | stack_queue | Given the empty stack or queue, when reading or removing, then the answer is none and it stays empty |
| DS-STACKQUEUE-05 | stack_queue | Given a stack and a queue, when updating, then the old versions are unchanged |
| DS-STACKQUEUE-06 | stack_queue | Given any items, when computing next-greater indices, then they match the quadratic definition |
| DS-STACKQUEUE-07 | stack_queue | Given a known list, when asking next greater values, then the textbook answer comes out |
| DS-STACKQUEUE-08 | stack_queue | Given 200000 increasing items, when computing next-greater indices, then the first, an inner and the last answer are right |
| DS-LINKEDLIST-01 | linked_list | Given any items, when pushed at the back, then forward is the input order and backward is its reverse |
| DS-LINKEDLIST-02 | linked_list | Given any items, when pushed at the front, then forward is the reverse of the input order |
| DS-LINKEDLIST-03 | linked_list | Given a handle, when inserting after it, then the new element sits right after it |
| DS-LINKEDLIST-04 | linked_list | Given a handle, when removing it, then the element is gone from both directions and the list stays consistent |
| DS-LINKEDLIST-05 | linked_list | Given a removed element whose slot was reused, when using the old handle, then it is rejected |
| DS-LINKEDLIST-06 | linked_list | Given a list, when updating, then the old version is unchanged |
| DS-LINKEDLIST-07 | linked_list | Given random pushes, inserts and removals, when checking the structure, then the invariants hold at every step |
| DS-LINKEDLIST-08 | linked_list | Given the empty list, when reading, then it is empty and a handle that is out of range is rejected |
| DS-AVLTREE-01 | avl_tree | Given any items, when inserted, then toSeq is the sorted distinct items and the AVL invariant holds |
| DS-AVLTREE-02 | avl_tree | Given any items, when asking contains, then it is true exactly for the inserted items |
| DS-AVLTREE-03 | avl_tree | Given random inserts and deletes, when checking the structure, then the balance invariant holds at every step |
| DS-AVLTREE-04 | avl_tree | Given any items and one of them, when deleting it, then it is gone and the rest remain |
| DS-AVLTREE-05 | avl_tree | Given sorted inserts, when measuring the height, then it stays logarithmic where a plain BST would be a list |
| DS-AVLTREE-06 | avl_tree | Given the four shapes that need a rotation, when inserting three items, then each ends with height 2 and sorted contents |
| DS-AVLTREE-07 | avl_tree | Given a tree, when inserting or deleting, then the old version is unchanged |
| DS-AVLTREE-08 | avl_tree | Given the empty tree, when querying, then it has no smallest and delete keeps it empty |
