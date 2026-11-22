# Sources and their licences

The catalog holds only these 210 sources (ADR-NCK-0005): articles and chapters, each chosen because
it explains the concept of a page, from sites whose licences were read on 2026-11-22:

| Site | Sources | Licence | Where the licence was read |
|---|---|---|---|
| English Wikipedia | 164 | CC-BY-SA-4.0 | the notice at the foot of each article |
| English Wikibooks | 1 | CC-BY-SA-4.0 | the notice at the foot of each page |
| cp-algorithms | 34 | CC-BY-SA-4.0 | the LICENSE file of the site's repository |
| Jeff Erickson, *Algorithms* | 1 | CC-BY-4.0 | the course page: the textbook is CC BY 4.0 (his other lecture notes are CC BY-NC-SA and are not cited) |
| Open Data Structures | 1 | CC-BY-2.5 | the home page's licence link |
| Erlang/OTP documentation | 2 | Apache-2.0 | the licence of the Erlang/OTP repository, which holds the documentation |
| Rust documentation (standard library, The Rust Programming Language, Rust by Example) | 6 | MIT, Apache-2.0 | the LICENSE-MIT and LICENSE-APACHE files of the rust-lang repositories |
| Go standard library documentation | 1 | BSD-3-Clause | the licence pkg.go.dev shows for the package |

Every licence allows use, copying, modification and distribution for any purpose, commercial use
included (`commercialLicenses` in free-books-catalog's `src/free_books_catalog/licences.nim`;
catalog_build refuses any other because `catalog/config.json` sets `"commercialOnly": true`, and
NCK-SRC-01 checks the committed catalog). Which page cites which source, and what each covers, is in
`catalog/citations.json`; `tools/cite_sources` writes the pages' Sources sections from it.

Original writing is marked on the page itself, in an "Original writing:" paragraph of its Sources
section: 2 pages are entirely original, because no source on these sites explains their
concept; 36 pages cite sources that explain part of the page, and the note above that
paragraph says what the rest is. The other 121 pages cite sources that explain their concept.
No page copies text from a source.

| Source | Catalog ID | Licence |
|---|---|---|
| [Greedy Algorithms (Erickson, Algorithms, ch. 4)](https://jeffe.cs.illinois.edu/teaching/algorithms/book/04-greedy.pdf) | `3e23f4f0ff0fa382` | CC-BY-4.0 |
| [gen_server (Erlang/OTP documentation)](https://www.erlang.org/doc/apps/stdlib/gen_server.html) | `50fc785f1d11793d` | Apache-2.0 |
| [Supervisor Behaviour (Erlang/OTP documentation)](https://www.erlang.org/doc/system/sup_princ.html) | `1b179470b870e5fe` | Apache-2.0 |
| [time package (Go standard library)](https://pkg.go.dev/time) | `3b680b9eeb9b9357` | BSD-3-Clause |
| [Open Data Structures (Open Data Structures)](https://opendatastructures.org/) | `fc4e34ece13d1024` | CC-BY-2.5 |
| [An Example Program Using Structs (The Rust Programming Language)](https://doc.rust-lang.org/book/ch05-02-example-structs.html) | `f0e6847a3be7cb1a` | MIT, Apache-2.0 |
| [Instant in std::time (Rust documentation)](https://doc.rust-lang.org/std/time/struct.Instant.html) | `fac70fde463133fd` | MIT, Apache-2.0 |
| [Phantom type parameters (Rust by Example)](https://doc.rust-lang.org/rust-by-example/generics/phantom.html) | `cd8d67404b0062a7` | MIT, Apache-2.0 |
| [SystemTime in std::time (Rust documentation)](https://doc.rust-lang.org/std/time/struct.SystemTime.html) | `a6e401f95ff216b0` | MIT, Apache-2.0 |
| [Testcase: unit clarification (Rust by Example)](https://doc.rust-lang.org/rust-by-example/generics/phantom/testcase_units.html) | `25d9ba479ac54c14` | MIT, Apache-2.0 |
| [To panic! or Not to panic! (The Rust Programming Language)](https://doc.rust-lang.org/book/ch09-03-to-panic-or-not-to-panic.html) | `c356b95a27dce231` | MIT, Apache-2.0 |
| [Haskell/GADT (Wikibooks)](https://en.wikibooks.org/wiki/Haskell/GADT) | `853728b9583be562` | CC-BY-SA-4.0 |
| [ABA problem (Wikipedia)](https://en.wikipedia.org/wiki/ABA_problem) | `3825593c370bd0c8` | CC-BY-SA-4.0 |
| [Abstract factory pattern (Wikipedia)](https://en.wikipedia.org/wiki/Abstract_factory_pattern) | `90708edeeebbaec0` | CC-BY-SA-4.0 |
| [Actor model (Wikipedia)](https://en.wikipedia.org/wiki/Actor_model) | `ed4c9a778416dd3d` | CC-BY-SA-4.0 |
| [Adapter pattern (Wikipedia)](https://en.wikipedia.org/wiki/Adapter_pattern) | `4d60ff999bda0edc` | CC-BY-SA-4.0 |
| [Aho–Corasick algorithm (Wikipedia)](https://en.wikipedia.org/wiki/Aho–Corasick_algorithm) | `bef42d97ad17d164` | CC-BY-SA-4.0 |
| [Algebraic data type (Wikipedia)](https://en.wikipedia.org/wiki/Algebraic_data_type) | `274be44eb11a5120` | CC-BY-SA-4.0 |
| [Amortized analysis (Wikipedia)](https://en.wikipedia.org/wiki/Amortized_analysis) | `edf91049891fd604` | CC-BY-SA-4.0 |
| [Approximation algorithm (Wikipedia)](https://en.wikipedia.org/wiki/Approximation_algorithm) | `28fef639cb78d3cf` | CC-BY-SA-4.0 |
| [AVL tree (Wikipedia)](https://en.wikipedia.org/wiki/AVL_tree) | `90d54c10630371a8` | CC-BY-SA-4.0 |
| [B-tree (Wikipedia)](https://en.wikipedia.org/wiki/B-tree) | `e2d46598d62044cf` | CC-BY-SA-4.0 |
| [Backtracking (Wikipedia)](https://en.wikipedia.org/wiki/Backtracking) | `1b0ee88856ce430c` | CC-BY-SA-4.0 |
| [Bellman–Ford algorithm (Wikipedia)](https://en.wikipedia.org/wiki/Bellman–Ford_algorithm) | `8689564bc83fe8c3` | CC-BY-SA-4.0 |
| [Bidirectional transformation (Wikipedia)](https://en.wikipedia.org/wiki/Bidirectional_transformation) | `1ff6c768cd18f607` | CC-BY-SA-4.0 |
| [Big O notation (Wikipedia)](https://en.wikipedia.org/wiki/Big_O_notation) | `b8ef1d121edbbaa1` | CC-BY-SA-4.0 |
| [Binary heap (Wikipedia)](https://en.wikipedia.org/wiki/Binary_heap) | `6049ba2282773666` | CC-BY-SA-4.0 |
| [Binary search (Wikipedia)](https://en.wikipedia.org/wiki/Binary_search) | `c8557968cbf78e3c` | CC-BY-SA-4.0 |
| [Binary search tree (Wikipedia)](https://en.wikipedia.org/wiki/Binary_search_tree) | `b36958ca6fb6d551` | CC-BY-SA-4.0 |
| [Binomial heap (Wikipedia)](https://en.wikipedia.org/wiki/Binomial_heap) | `7be0194f5928bb1a` | CC-BY-SA-4.0 |
| [Bit array (Wikipedia)](https://en.wikipedia.org/wiki/Bit_array) | `5802d14abf6b676b` | CC-BY-SA-4.0 |
| [Bloom filter (Wikipedia)](https://en.wikipedia.org/wiki/Bloom_filter) | `413515022ebddaf4` | CC-BY-SA-4.0 |
| [Breadth-first search (Wikipedia)](https://en.wikipedia.org/wiki/Breadth-first_search) | `6215342ef1e70064` | CC-BY-SA-4.0 |
| [Bridge pattern (Wikipedia)](https://en.wikipedia.org/wiki/Bridge_pattern) | `33d2a5980598176a` | CC-BY-SA-4.0 |
| [Builder pattern (Wikipedia)](https://en.wikipedia.org/wiki/Builder_pattern) | `ccab06f28a5f5a68` | CC-BY-SA-4.0 |
| [Bulkhead pattern (Wikipedia)](https://en.wikipedia.org/wiki/Bulkhead_pattern) | `71a07163203c135d` | CC-BY-SA-4.0 |
| [Capability-based security (Wikipedia)](https://en.wikipedia.org/wiki/Capability-based_security) | `60e228e8e5a43305` | CC-BY-SA-4.0 |
| [Chain-of-responsibility pattern (Wikipedia)](https://en.wikipedia.org/wiki/Chain-of-responsibility_pattern) | `cfed21302ac49e11` | CC-BY-SA-4.0 |
| [Characterization test (Wikipedia)](https://en.wikipedia.org/wiki/Characterization_test) | `2980226ed868c08c` | CC-BY-SA-4.0 |
| [Circuit breaker design pattern (Wikipedia)](https://en.wikipedia.org/wiki/Circuit_breaker_design_pattern) | `b92abb9855f547cc` | CC-BY-SA-4.0 |
| [Code refactoring (Wikipedia)](https://en.wikipedia.org/wiki/Code_refactoring) | `e0da847236a95912` | CC-BY-SA-4.0 |
| [Command pattern (Wikipedia)](https://en.wikipedia.org/wiki/Command_pattern) | `01af3730c5bafb02` | CC-BY-SA-4.0 |
| [Command Query Responsibility Segregation (Wikipedia)](https://en.wikipedia.org/wiki/Command_Query_Responsibility_Segregation) | `71c13e74827733c2` | CC-BY-SA-4.0 |
| [Command–query separation (Wikipedia)](https://en.wikipedia.org/wiki/Command–query_separation) | `48f95b809a0f0b3b` | CC-BY-SA-4.0 |
| [Composite pattern (Wikipedia)](https://en.wikipedia.org/wiki/Composite_pattern) | `3848c6e9f83a85e4` | CC-BY-SA-4.0 |
| [Conflict-free replicated data type (Wikipedia)](https://en.wikipedia.org/wiki/Conflict-free_replicated_data_type) | `f1958593e8886b91` | CC-BY-SA-4.0 |
| [cons (Wikipedia)](https://en.wikipedia.org/wiki/Cons) | `e5af0e59bec4756b` | CC-BY-SA-4.0 |
| [Consistent hashing (Wikipedia)](https://en.wikipedia.org/wiki/Consistent_hashing) | `aa502798cd36de2d` | CC-BY-SA-4.0 |
| [Content-addressable storage (Wikipedia)](https://en.wikipedia.org/wiki/Content-addressable_storage) | `361f12a35168f674` | CC-BY-SA-4.0 |
| [Convex hull algorithms (Wikipedia)](https://en.wikipedia.org/wiki/Convex_hull_algorithms) | `b58547ede15087a4` | CC-BY-SA-4.0 |
| [Counting sort (Wikipedia)](https://en.wikipedia.org/wiki/Counting_sort) | `7c6682f61aee42a8` | CC-BY-SA-4.0 |
| [Cycle detection (Wikipedia)](https://en.wikipedia.org/wiki/Cycle_detection) | `fe7de4383fcec4dc` | CC-BY-SA-4.0 |
| [Data clump (Wikipedia)](https://en.wikipedia.org/wiki/Data_clump) | `18368b39df2a86d6` | CC-BY-SA-4.0 |
| [Decorator pattern (Wikipedia)](https://en.wikipedia.org/wiki/Decorator_pattern) | `7063af83192f3c1e` | CC-BY-SA-4.0 |
| [Dependency injection (Wikipedia)](https://en.wikipedia.org/wiki/Dependency_injection) | `5bc01215c554611d` | CC-BY-SA-4.0 |
| [Depth-first search (Wikipedia)](https://en.wikipedia.org/wiki/Depth-first_search) | `4d89433f773dee8d` | CC-BY-SA-4.0 |
| [Dijkstra's algorithm (Wikipedia)](https://en.wikipedia.org/wiki/Dijkstra's_algorithm) | `38cd287ed3ec9270` | CC-BY-SA-4.0 |
| [Disjoint-set data structure (Wikipedia)](https://en.wikipedia.org/wiki/Disjoint-set_data_structure) | `c1dc4985db70845e` | CC-BY-SA-4.0 |
| [Divide-and-conquer algorithm (Wikipedia)](https://en.wikipedia.org/wiki/Divide-and-conquer_algorithm) | `782bceea232d66dd` | CC-BY-SA-4.0 |
| [Domain-driven design (Wikipedia)](https://en.wikipedia.org/wiki/Domain-driven_design) | `d5502080b0bfb822` | CC-BY-SA-4.0 |
| [Double-ended queue (Wikipedia)](https://en.wikipedia.org/wiki/Double-ended_queue) | `99cefbe9562d9272` | CC-BY-SA-4.0 |
| [Doubly linked list (Wikipedia)](https://en.wikipedia.org/wiki/Doubly_linked_list) | `37174714b555d156` | CC-BY-SA-4.0 |
| [E (programming language) (Wikipedia)](https://en.wikipedia.org/wiki/E_(programming_language)) | `652c8ebe27b4b6a1` | CC-BY-SA-4.0 |
| [Edit distance (Wikipedia)](https://en.wikipedia.org/wiki/Edit_distance) | `1398dddb85ced758` | CC-BY-SA-4.0 |
| [Elm (programming language) (Wikipedia)](https://en.wikipedia.org/wiki/Elm_(programming_language)) | `ac19b0af9d8633b8` | CC-BY-SA-4.0 |
| [Eulerian path (Wikipedia)](https://en.wikipedia.org/wiki/Eulerian_path) | `8c716cce20eb0265` | CC-BY-SA-4.0 |
| [Event store (Wikipedia)](https://en.wikipedia.org/wiki/Event_store) | `bf73fcd9a3f53a30` | CC-BY-SA-4.0 |
| [Exponential backoff (Wikipedia)](https://en.wikipedia.org/wiki/Exponential_backoff) | `73afa3555eda02ea` | CC-BY-SA-4.0 |
| [Exponentiation by squaring (Wikipedia)](https://en.wikipedia.org/wiki/Exponentiation_by_squaring) | `04c79e1e35914fe8` | CC-BY-SA-4.0 |
| [Expression problem (Wikipedia)](https://en.wikipedia.org/wiki/Expression_problem) | `fe89d8ef736ee3c0` | CC-BY-SA-4.0 |
| [External sorting (Wikipedia)](https://en.wikipedia.org/wiki/External_sorting) | `6abe18a4d21811b2` | CC-BY-SA-4.0 |
| [Facade pattern (Wikipedia)](https://en.wikipedia.org/wiki/Facade_pattern) | `2711392e55cdaff1` | CC-BY-SA-4.0 |
| [Factory method pattern (Wikipedia)](https://en.wikipedia.org/wiki/Factory_method_pattern) | `ae149a41a0a65001` | CC-BY-SA-4.0 |
| [Fenwick tree (Wikipedia)](https://en.wikipedia.org/wiki/Fenwick_tree) | `2824f929bb9362ca` | CC-BY-SA-4.0 |
| [Finite-state machine (Wikipedia)](https://en.wikipedia.org/wiki/Finite-state_machine) | `6f9825f10e9b70ff` | CC-BY-SA-4.0 |
| [Floyd–Warshall algorithm (Wikipedia)](https://en.wikipedia.org/wiki/Floyd–Warshall_algorithm) | `8f552a6506e48e21` | CC-BY-SA-4.0 |
| [Flyweight pattern (Wikipedia)](https://en.wikipedia.org/wiki/Flyweight_pattern) | `d881a07f5675a646` | CC-BY-SA-4.0 |
| [Fold (higher-order function) (Wikipedia)](https://en.wikipedia.org/wiki/Fold_(higher-order_function)) | `89ec031e9b5603b0` | CC-BY-SA-4.0 |
| [Function composition (computer science) (Wikipedia)](https://en.wikipedia.org/wiki/Function_composition_(computer_science)) | `d90148315f9e0d2b` | CC-BY-SA-4.0 |
| [Functor (functional programming) (Wikipedia)](https://en.wikipedia.org/wiki/Functor_(functional_programming)) | `60667cab88e88a2c` | CC-BY-SA-4.0 |
| [Graph (abstract data type) (Wikipedia)](https://en.wikipedia.org/wiki/Graph_(abstract_data_type)) | `a1da01744743a89c` | CC-BY-SA-4.0 |
| [Greedy algorithm (Wikipedia)](https://en.wikipedia.org/wiki/Greedy_algorithm) | `6ba34697d3d84690` | CC-BY-SA-4.0 |
| [Handle (computing) (Wikipedia)](https://en.wikipedia.org/wiki/Handle_(computing)) | `c075eab36084316e` | CC-BY-SA-4.0 |
| [Hash array mapped trie (Wikipedia)](https://en.wikipedia.org/wiki/Hash_array_mapped_trie) | `686a74b9cb147d93` | CC-BY-SA-4.0 |
| [Hash table (Wikipedia)](https://en.wikipedia.org/wiki/Hash_table) | `37e2a72c655f9ec1` | CC-BY-SA-4.0 |
| [Heapsort (Wikipedia)](https://en.wikipedia.org/wiki/Heapsort) | `9199bdf357608518` | CC-BY-SA-4.0 |
| [Huffman coding (Wikipedia)](https://en.wikipedia.org/wiki/Huffman_coding) | `2a69d73160f9ef6e` | CC-BY-SA-4.0 |
| [Idempotence (Wikipedia)](https://en.wikipedia.org/wiki/Idempotence) | `4af7eac48ba49203` | CC-BY-SA-4.0 |
| [Immutable object (Wikipedia)](https://en.wikipedia.org/wiki/Immutable_object) | `24f1092fea59a7ac` | CC-BY-SA-4.0 |
| [Inbox and outbox pattern (Wikipedia)](https://en.wikipedia.org/wiki/Inbox_and_outbox_pattern) | `a6ccc58b0112e6cd` | CC-BY-SA-4.0 |
| [Insertion sort (Wikipedia)](https://en.wikipedia.org/wiki/Insertion_sort) | `8a5e103ea8f12a60` | CC-BY-SA-4.0 |
| [Interpreter pattern (Wikipedia)](https://en.wikipedia.org/wiki/Interpreter_pattern) | `1656f17a2f153c91` | CC-BY-SA-4.0 |
| [Iterator pattern (Wikipedia)](https://en.wikipedia.org/wiki/Iterator_pattern) | `424aa21b5f8ea285` | CC-BY-SA-4.0 |
| [k-d tree (Wikipedia)](https://en.wikipedia.org/wiki/K-d_tree) | `92b9cbd0c495c72f` | CC-BY-SA-4.0 |
| [Knapsack problem (Wikipedia)](https://en.wikipedia.org/wiki/Knapsack_problem) | `e745e029009d8860` | CC-BY-SA-4.0 |
| [Knuth–Morris–Pratt algorithm (Wikipedia)](https://en.wikipedia.org/wiki/Knuth–Morris–Pratt_algorithm) | `6257bfc23c0c0667` | CC-BY-SA-4.0 |
| [Kruskal's algorithm (Wikipedia)](https://en.wikipedia.org/wiki/Kruskal's_algorithm) | `0b0940e9bca772a9` | CC-BY-SA-4.0 |
| [Lazy evaluation (Wikipedia)](https://en.wikipedia.org/wiki/Lazy_evaluation) | `486e6acf9a6b74f3` | CC-BY-SA-4.0 |
| [LCP array (Wikipedia)](https://en.wikipedia.org/wiki/LCP_array) | `f8ccdccce79a7e47` | CC-BY-SA-4.0 |
| [Leftist tree (Wikipedia)](https://en.wikipedia.org/wiki/Leftist_tree) | `2d432cb2a7e0590e` | CC-BY-SA-4.0 |
| [Levenshtein distance (Wikipedia)](https://en.wikipedia.org/wiki/Levenshtein_distance) | `7abc42e6a83e1359` | CC-BY-SA-4.0 |
| [Linear probing (Wikipedia)](https://en.wikipedia.org/wiki/Linear_probing) | `3def4e5120f23b4d` | CC-BY-SA-4.0 |
| [Linked list (Wikipedia)](https://en.wikipedia.org/wiki/Linked_list) | `3bdf34b2f0cb5bc8` | CC-BY-SA-4.0 |
| [Long-running transaction (Wikipedia)](https://en.wikipedia.org/wiki/Long-running_transaction) | `a8bdbf3842cb854d` | CC-BY-SA-4.0 |
| [Longest common subsequence (Wikipedia)](https://en.wikipedia.org/wiki/Longest_common_subsequence) | `dcf17a7de58a4454` | CC-BY-SA-4.0 |
| [Longest increasing subsequence (Wikipedia)](https://en.wikipedia.org/wiki/Longest_increasing_subsequence) | `8b8037d0f8b298fe` | CC-BY-SA-4.0 |
| [Lowest common ancestor (Wikipedia)](https://en.wikipedia.org/wiki/Lowest_common_ancestor) | `842b7bc536b91e20` | CC-BY-SA-4.0 |
| [Master theorem (analysis of algorithms) (Wikipedia)](https://en.wikipedia.org/wiki/Master_theorem_(analysis_of_algorithms)) | `3aad9115b6daab2c` | CC-BY-SA-4.0 |
| [Maximum flow problem (Wikipedia)](https://en.wikipedia.org/wiki/Maximum_flow_problem) | `3f809c7827ad8aad` | CC-BY-SA-4.0 |
| [Mediator pattern (Wikipedia)](https://en.wikipedia.org/wiki/Mediator_pattern) | `cf9cd72c69e05e1e` | CC-BY-SA-4.0 |
| [Memento pattern (Wikipedia)](https://en.wikipedia.org/wiki/Memento_pattern) | `f60fd4a334285414` | CC-BY-SA-4.0 |
| [Memoization (Wikipedia)](https://en.wikipedia.org/wiki/Memoization) | `6bbca9dba1ba391c` | CC-BY-SA-4.0 |
| [Merge (version control) (Wikipedia)](https://en.wikipedia.org/wiki/Merge_(version_control)) | `adf990e8cba6b2c0` | CC-BY-SA-4.0 |
| [Merge sort (Wikipedia)](https://en.wikipedia.org/wiki/Merge_sort) | `85c3b378a353c433` | CC-BY-SA-4.0 |
| [Merkle tree (Wikipedia)](https://en.wikipedia.org/wiki/Merkle_tree) | `910b65056f3e5195` | CC-BY-SA-4.0 |
| [Monad (functional programming) (Wikipedia)](https://en.wikipedia.org/wiki/Monad_(functional_programming)) | `af5c8783453c7e24` | CC-BY-SA-4.0 |
| [Monoid (Wikipedia)](https://en.wikipedia.org/wiki/Monoid) | `70eabc800658e0ec` | CC-BY-SA-4.0 |
| [Multitier architecture (Wikipedia)](https://en.wikipedia.org/wiki/Multitier_architecture) | `f0c3d752953e20ab` | CC-BY-SA-4.0 |
| [Object-capability model (Wikipedia)](https://en.wikipedia.org/wiki/Object-capability_model) | `1a834c59905e2488` | CC-BY-SA-4.0 |
| [Observer pattern (Wikipedia)](https://en.wikipedia.org/wiki/Observer_pattern) | `ece9362639e00fb9` | CC-BY-SA-4.0 |
| [Option type (Wikipedia)](https://en.wikipedia.org/wiki/Option_type) | `12a6d365d35eb574` | CC-BY-SA-4.0 |
| [Pairing heap (Wikipedia)](https://en.wikipedia.org/wiki/Pairing_heap) | `a4e73ae2b00d9619` | CC-BY-SA-4.0 |
| [Parser combinator (Wikipedia)](https://en.wikipedia.org/wiki/Parser_combinator) | `ec3d2129b08698d4` | CC-BY-SA-4.0 |
| [Persistent data structure (Wikipedia)](https://en.wikipedia.org/wiki/Persistent_data_structure) | `93f436ec1b39312a` | CC-BY-SA-4.0 |
| [Pipeline (software) (Wikipedia)](https://en.wikipedia.org/wiki/Pipeline_(software)) | `94248ee8312149b5` | CC-BY-SA-4.0 |
| [Prefix sum (Wikipedia)](https://en.wikipedia.org/wiki/Prefix_sum) | `05e6a4a78b12dd6a` | CC-BY-SA-4.0 |
| [Prim's algorithm (Wikipedia)](https://en.wikipedia.org/wiki/Prim's_algorithm) | `73a124478b696126` | CC-BY-SA-4.0 |
| [Prototype pattern (Wikipedia)](https://en.wikipedia.org/wiki/Prototype_pattern) | `c417d4494cef937d` | CC-BY-SA-4.0 |
| [Proxy pattern (Wikipedia)](https://en.wikipedia.org/wiki/Proxy_pattern) | `45e160dbc6217c27` | CC-BY-SA-4.0 |
| [Pure function (Wikipedia)](https://en.wikipedia.org/wiki/Pure_function) | `2c1a1cc20924cd71` | CC-BY-SA-4.0 |
| [Purely functional data structure (Wikipedia)](https://en.wikipedia.org/wiki/Purely_functional_data_structure) | `4fb9d2a834ff7720` | CC-BY-SA-4.0 |
| [Queue (abstract data type) (Wikipedia)](https://en.wikipedia.org/wiki/Queue_(abstract_data_type)) | `272fbcd73a9312b1` | CC-BY-SA-4.0 |
| [Quicksort (Wikipedia)](https://en.wikipedia.org/wiki/Quicksort) | `522897bc50694da5` | CC-BY-SA-4.0 |
| [Rabin–Karp algorithm (Wikipedia)](https://en.wikipedia.org/wiki/Rabin–Karp_algorithm) | `e328397a112aae43` | CC-BY-SA-4.0 |
| [Radix sort (Wikipedia)](https://en.wikipedia.org/wiki/Radix_sort) | `83e988650c438ef1` | CC-BY-SA-4.0 |
| [Range minimum query (Wikipedia)](https://en.wikipedia.org/wiki/Range_minimum_query) | `a5de8e339a67b9cb` | CC-BY-SA-4.0 |
| [Red–black tree (Wikipedia)](https://en.wikipedia.org/wiki/Red–black_tree) | `7d34e4bf24e3cb08` | CC-BY-SA-4.0 |
| [Referential transparency (Wikipedia)](https://en.wikipedia.org/wiki/Referential_transparency) | `5d5d2690cf234c94` | CC-BY-SA-4.0 |
| [Rename (computing) (Wikipedia)](https://en.wikipedia.org/wiki/Rename_(computing)) | `587cf64fe7ab500e` | CC-BY-SA-4.0 |
| [Request–response (Wikipedia)](https://en.wikipedia.org/wiki/Request–response) | `6a0bb33166dabc69` | CC-BY-SA-4.0 |
| [Result type (Wikipedia)](https://en.wikipedia.org/wiki/Result_type) | `3e2f9c9c5f6bad38` | CC-BY-SA-4.0 |
| [Segment tree (Wikipedia)](https://en.wikipedia.org/wiki/Segment_tree) | `e63962521a8e8248` | CC-BY-SA-4.0 |
| [Selection sort (Wikipedia)](https://en.wikipedia.org/wiki/Selection_sort) | `36efee613237a769` | CC-BY-SA-4.0 |
| [Self-balancing binary search tree (Wikipedia)](https://en.wikipedia.org/wiki/Self-balancing_binary_search_tree) | `92fb42677af37dfc` | CC-BY-SA-4.0 |
| [Shellsort (Wikipedia)](https://en.wikipedia.org/wiki/Shellsort) | `fb7e4f1d9c1706a4` | CC-BY-SA-4.0 |
| [Side effect (computer science) (Wikipedia)](https://en.wikipedia.org/wiki/Side_effect_(computer_science)) | `130ad4e198fe734f` | CC-BY-SA-4.0 |
| [Sieve of Eratosthenes (Wikipedia)](https://en.wikipedia.org/wiki/Sieve_of_Eratosthenes) | `78f755448f8a37a2` | CC-BY-SA-4.0 |
| [Singleton pattern (Wikipedia)](https://en.wikipedia.org/wiki/Singleton_pattern) | `7425770abb5f06c2` | CC-BY-SA-4.0 |
| [Skew binary number system (Wikipedia)](https://en.wikipedia.org/wiki/Skew_binary_number_system) | `5e7db9cb96450d0c` | CC-BY-SA-4.0 |
| [Splay tree (Wikipedia)](https://en.wikipedia.org/wiki/Splay_tree) | `05fb7d420d53954a` | CC-BY-SA-4.0 |
| [Stack (abstract data type) (Wikipedia)](https://en.wikipedia.org/wiki/Stack_(abstract_data_type)) | `780b4ebe442ea1d4` | CC-BY-SA-4.0 |
| [State pattern (Wikipedia)](https://en.wikipedia.org/wiki/State_pattern) | `96b03f277d46e69e` | CC-BY-SA-4.0 |
| [Strangler fig pattern (Wikipedia)](https://en.wikipedia.org/wiki/Strangler_fig_pattern) | `59217df8cf9ce10e` | CC-BY-SA-4.0 |
| [Strategy pattern (Wikipedia)](https://en.wikipedia.org/wiki/Strategy_pattern) | `5b50628195d322fa` | CC-BY-SA-4.0 |
| [Stream (abstract data type) (Wikipedia)](https://en.wikipedia.org/wiki/Stream_(abstract_data_type)) | `c9ac1c7790abbf34` | CC-BY-SA-4.0 |
| [Strongly connected component (Wikipedia)](https://en.wikipedia.org/wiki/Strongly_connected_component) | `135b2b7c405eb17a` | CC-BY-SA-4.0 |
| [Subset sum problem (Wikipedia)](https://en.wikipedia.org/wiki/Subset_sum_problem) | `18d03a640694a580` | CC-BY-SA-4.0 |
| [Suffix array (Wikipedia)](https://en.wikipedia.org/wiki/Suffix_array) | `5af7011ac3c7dda9` | CC-BY-SA-4.0 |
| [Suffix tree (Wikipedia)](https://en.wikipedia.org/wiki/Suffix_tree) | `dd78d02626bf0b24` | CC-BY-SA-4.0 |
| [Summed-area table (Wikipedia)](https://en.wikipedia.org/wiki/Summed-area_table) | `6589db1cad040086` | CC-BY-SA-4.0 |
| [sync (Unix) (Wikipedia)](https://en.wikipedia.org/wiki/Sync_(Unix)) | `a8ef5a83069f53fb` | CC-BY-SA-4.0 |
| [Tail call (Wikipedia)](https://en.wikipedia.org/wiki/Tail_call) | `992f110785fdcdd9` | CC-BY-SA-4.0 |
| [Tail drop (Wikipedia)](https://en.wikipedia.org/wiki/Tail_drop) | `eaea7dde179723dc` | CC-BY-SA-4.0 |
| [Tarjan's strongly connected components algorithm (Wikipedia)](https://en.wikipedia.org/wiki/Tarjan's_strongly_connected_components_algorithm) | `73daa642c7d48c08` | CC-BY-SA-4.0 |
| [Template method pattern (Wikipedia)](https://en.wikipedia.org/wiki/Template_method_pattern) | `98db8836fc706621` | CC-BY-SA-4.0 |
| [Time complexity (Wikipedia)](https://en.wikipedia.org/wiki/Time_complexity) | `0f84110bc6fb9a48` | CC-BY-SA-4.0 |
| [Token bucket (Wikipedia)](https://en.wikipedia.org/wiki/Token_bucket) | `6b4792f83e33c96a` | CC-BY-SA-4.0 |
| [Topological sorting (Wikipedia)](https://en.wikipedia.org/wiki/Topological_sorting) | `06a9434c68869f12` | CC-BY-SA-4.0 |
| [Treap (Wikipedia)](https://en.wikipedia.org/wiki/Treap) | `ea8f95762cd9d68a` | CC-BY-SA-4.0 |
| [Trie (Wikipedia)](https://en.wikipedia.org/wiki/Trie) | `bf13c7c4d518660e` | CC-BY-SA-4.0 |
| [Type class (Wikipedia)](https://en.wikipedia.org/wiki/Type_class) | `15270b25509ca67d` | CC-BY-SA-4.0 |
| [Typestate analysis (Wikipedia)](https://en.wikipedia.org/wiki/Typestate_analysis) | `e9f9521ff80ffabe` | CC-BY-SA-4.0 |
| [Vertex cover (Wikipedia)](https://en.wikipedia.org/wiki/Vertex_cover) | `77b1d95b642d048c` | CC-BY-SA-4.0 |
| [Visitor pattern (Wikipedia)](https://en.wikipedia.org/wiki/Visitor_pattern) | `2c7c9a64ac2b2ebd` | CC-BY-SA-4.0 |
| [Write-ahead logging (Wikipedia)](https://en.wikipedia.org/wiki/Write-ahead_logging) | `a9185e6d8497b427` | CC-BY-SA-4.0 |
| [Zipper (data structure) (Wikipedia)](https://en.wikipedia.org/wiki/Zipper_(data_structure)) | `74e4f056ab8ab490` | CC-BY-SA-4.0 |
| [Aho-Corasick algorithm (cp-algorithms)](https://cp-algorithms.com/string/aho_corasick.html) | `7c9bae87004ab621` | CC-BY-SA-4.0 |
| [Bellman-Ford - finding shortest paths with negative weights (cp-algorithms)](https://cp-algorithms.com/graph/bellman_ford.html) | `eeed39e57bca4d59` | CC-BY-SA-4.0 |
| [Binary Exponentiation (cp-algorithms)](https://cp-algorithms.com/algebra/binary-exp.html) | `ef24a19086be350f` | CC-BY-SA-4.0 |
| [Binary Search (cp-algorithms)](https://cp-algorithms.com/num_methods/binary_search.html) | `c240699e92d3dd65` | CC-BY-SA-4.0 |
| [Breadth First Search (cp-algorithms)](https://cp-algorithms.com/graph/breadth-first-search.html) | `4d69a54a5b23646a` | CC-BY-SA-4.0 |
| [Checking a graph for acyclicity and finding a cycle in O(M) (cp-algorithms)](https://cp-algorithms.com/graph/finding-cycle.html) | `aa18a44ed6b8633a` | CC-BY-SA-4.0 |
| [Convex hull construction (cp-algorithms)](https://cp-algorithms.com/geometry/convex-hull.html) | `afbdfaa6bbd570af` | CC-BY-SA-4.0 |
| [Depth First Search (cp-algorithms)](https://cp-algorithms.com/graph/depth-first-search.html) | `fe1d4be54cbfecb9` | CC-BY-SA-4.0 |
| [Dijkstra - finding shortest paths from given vertex (cp-algorithms)](https://cp-algorithms.com/graph/dijkstra.html) | `a02954f71a465fec` | CC-BY-SA-4.0 |
| [Disjoint Set Union (cp-algorithms)](https://cp-algorithms.com/data_structures/disjoint_set_union.html) | `273c7482c4c715b8` | CC-BY-SA-4.0 |
| [Extended Euclidean Algorithm (cp-algorithms)](https://cp-algorithms.com/algebra/extended-euclid-algorithm.html) | `08d8fc83218a2108` | CC-BY-SA-4.0 |
| [Fenwick Tree (cp-algorithms)](https://cp-algorithms.com/data_structures/fenwick.html) | `f872e3eda8f0f8dc` | CC-BY-SA-4.0 |
| [Fibonacci Numbers (cp-algorithms)](https://cp-algorithms.com/algebra/fibonacci-numbers.html) | `402d11649229d101` | CC-BY-SA-4.0 |
| [Finding the Eulerian path in O(M) (cp-algorithms)](https://cp-algorithms.com/graph/euler_path.html) | `628f51431c357b81` | CC-BY-SA-4.0 |
| [Floyd-Warshall - finding all shortest paths (cp-algorithms)](https://cp-algorithms.com/graph/all-pair-shortest-path-floyd-warshall.html) | `a7d6db829063b6f7` | CC-BY-SA-4.0 |
| [Knapsack Problem (cp-algorithms)](https://cp-algorithms.com/dynamic_programming/knapsack.html) | `5f07ae1db436c53b` | CC-BY-SA-4.0 |
| [Kuhn's Algorithm - Maximum Bipartite Matching (cp-algorithms)](https://cp-algorithms.com/graph/kuhn_maximum_bipartite_matching.html) | `363675dd645a4daa` | CC-BY-SA-4.0 |
| [Longest increasing subsequence (cp-algorithms)](https://cp-algorithms.com/dynamic_programming/longest_increasing_subsequence.html) | `081c8714254e799d` | CC-BY-SA-4.0 |
| [Lowest Common Ancestor - Binary Lifting (cp-algorithms)](https://cp-algorithms.com/graph/lca_binary_lifting.html) | `6c938ccdd8251292` | CC-BY-SA-4.0 |
| [Maximum flow - Ford-Fulkerson and Edmonds-Karp (cp-algorithms)](https://cp-algorithms.com/graph/edmonds_karp.html) | `a10e7e0b3abea7fb` | CC-BY-SA-4.0 |
| [Minimum Spanning Tree - Kruskal (cp-algorithms)](https://cp-algorithms.com/graph/mst_kruskal.html) | `5039434dec51cab4` | CC-BY-SA-4.0 |
| [Minimum Spanning Tree - Prim's Algorithm (cp-algorithms)](https://cp-algorithms.com/graph/mst_prim.html) | `fe1cf6fbf2221a75` | CC-BY-SA-4.0 |
| [Minimum Stack / Minimum Queue (cp-algorithms)](https://cp-algorithms.com/data_structures/stack_queue_modification.html) | `8e0fb2ad30794afa` | CC-BY-SA-4.0 |
| [Modular Inverse (cp-algorithms)](https://cp-algorithms.com/algebra/module-inverse.html) | `2a46e7824597cb31` | CC-BY-SA-4.0 |
| [Prefix function - Knuth-Morris-Pratt (cp-algorithms)](https://cp-algorithms.com/string/prefix-function.html) | `01393ccf85886fee` | CC-BY-SA-4.0 |
| [Rabin-Karp for String Matching (cp-algorithms)](https://cp-algorithms.com/string/rabin-karp.html) | `a0522eb9caff68b2` | CC-BY-SA-4.0 |
| [Segment Tree (cp-algorithms)](https://cp-algorithms.com/data_structures/segment_tree.html) | `d74a1064f5770f8f` | CC-BY-SA-4.0 |
| [Sieve of Eratosthenes (cp-algorithms)](https://cp-algorithms.com/algebra/sieve-of-eratosthenes.html) | `aad3769fa4532c8c` | CC-BY-SA-4.0 |
| [Sparse Table (cp-algorithms)](https://cp-algorithms.com/data_structures/sparse-table.html) | `5d1bbd84e89fe886` | CC-BY-SA-4.0 |
| [Strongly Connected Components and Condensation Graph (cp-algorithms)](https://cp-algorithms.com/graph/strongly-connected-components.html) | `3b463005afa8d22b` | CC-BY-SA-4.0 |
| [Suffix Array (cp-algorithms)](https://cp-algorithms.com/string/suffix-array.html) | `5e9128827e51308c` | CC-BY-SA-4.0 |
| [Topological Sorting (cp-algorithms)](https://cp-algorithms.com/graph/topological-sort.html) | `8883b90e8f4a0698` | CC-BY-SA-4.0 |
| [Treap (cp-algorithms)](https://cp-algorithms.com/data_structures/treap.html) | `18db0f05b9aafd69` | CC-BY-SA-4.0 |
| [Z-function (cp-algorithms)](https://cp-algorithms.com/string/z-function.html) | `05ac582e205bd9f8` | CC-BY-SA-4.0 |
