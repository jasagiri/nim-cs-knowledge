---
name: nim-data-structures
description: >-
  Choose, write and review persistent (functional) data structures in Nim: cons list, banker's
  queue, deque, leftist/pairing/binomial heaps, red-black tree, skew-binary list, persistent
  vector, HAMT, trie, zipper, persistent union-find, segment tree, Bloom filter and Merkle tree with a content-addressed store, plus the
  classic textbook structures as values (hash table, binary heap, stack and queue, arena linked
  list, BST, AVL tree, B-tree, treap, splay tree, k-d tree, Fenwick tree, sparse table, bit vector,
  suffix trie). Load it when
  a task needs a queue, priority queue, ordered or hash map, indexed sequence or prefix search
  whose old versions must stay valid, when an update must not mutate its argument, or when you
  must pick a structure for an access pattern. Every structure is a Nim 2.4 module with
  `func` routines, `Option`/`Result` failure and tested laws.
---

# Nim data structures: persistent and functional

Every structure in `src/nimcs/ds/` is a **value**: an update returns a new value and the old
one stays valid. The tree and list structures are **persistent**: unchanged parts are shared through
`ref` to immutable nodes, so an update copies only a path, not the whole structure. The flat
textbook structures (`hash_table`, `binary_heap`, `stack_queue`, `linked_list`, `fenwick_tree`,
`sparse_table`, `bit_vector`) keep one `seq` and copy it on each update, O(n); build them in one call
(`fromPairs`, `fromSeq`, ...) or keep a `var` local to one routine, and see their pages for the cost. The modules follow the repository's style (ADR-NCK-0002):
public routines are `func` with `{.raises: [].}`, absence is `Option`, a failure with a reason is
`Result` (`nimcs/fp/result`), shapes are plain `object`s, nothing reads the clock, a random
source or a hash order. Each structure has a details page with its laws, complexity and pitfalls;
the laws are spec IDs (`docs/spec/ds.md`) checked by property tests.

Inside this repository, import the module (`import nimcs/<area>/<name>`). In another project the
modules are not a published package: copy the shape from the details page into your own file, or
add this repository's `src/` to the compiler path (`--path:"<repo>/src"`).

Your own task (a scratch directory, another project): the page's Public API section lists every
exported signature of its module. When the task fixes names, fields or a signature the module does
not have (`Payment(id, cents)` instead of `Command(key, amount)`), write your own types and routines
in your file from the page's shape and laws: the algorithm, the laws, the tests and the example's
layout (its fields and steps) carry over, the type and routine names do not (use the task's names:
`circle`, not the example's `square`). A formula the task fixes wins over a module law that differs
(a rounding direction); say the difference in the doc comment. An optional parameter of the source
(`pct?: number`) becomes `Option[T] = none(T)`. Do not convert between your types and the module's on every call;
a thin wrapper that only names the module's operations for the task (an `OrderedMap` over `hamt`, a
`TaskQueue` over `leftist_heap`) is fine. The
spec-row steps in this skill (`docs/spec`, `# SPEC:` lines, `tests/test_<area>_*.nim`) are for adding
a module to this repository; for your own code, put `std/unittest` tests with Given-When-Then names
in `test_<name>.nim` beside it, with no spec file. `propcheck` and `std/unittest` both define
`check`; they take different arguments, so both work in one file. A callback parameter of a
`func` is typed `proc(i: int): bool {.noSideEffect, raises: [].}`: add these pragmas to a fixed
signature that says `proc(i: int): bool`, since a `func` cannot call a callback that may have
effects or raise. Import only what the file uses (an unused import is a compile error under the
strict settings): `Option` needs `std/options`, `Result` needs `nimcs/fp/result`, and a file whose exported
routines return `Result` also writes `export result`, or a test that imports only that file fails
with "undeclared field: 'isErr'"; that test then needs no import of its own. Guard clauses with an early
`return err(...)` are fine in a `func`. A plain object (no `case`) gets `==` field by field, a sealed one (private fields,
`{.requiresInit.}`) included; an object variant does not. `opt.get` on
`none` is a defect, not an exception, so a `{.raises: [].}` func may call it after `isSome`. A `func`
may change its own `result` and its local variables (`result.log.add x`), never what its caller sees. When the file
uses `Result`, import it by default: if `import nimcs/fp/result` compiles (a prepared run directory's `nim.cfg` puts `src/` on the path),
use it. Only when it does not, copy this `Result` (the repository's adds `map`, `flatMap` and `==`):

```nim
type Result*[T, E] = object
  case isOk*: bool
  of true: value*: T
  of false: error*: E

func ok*[T, E](v: T; _: typedesc[E]): Result[T, E] {.raises: [].} = Result[T, E](isOk: true, value: v)
func err*[T, E](_: typedesc[T]; e: E): Result[T, E] {.raises: [].} = Result[T, E](isOk: false, error: e)
func isErr*[T, E](r: Result[T, E]): bool {.raises: [].} = not r.isOk

doAssert ok(3, string).value == 3 and err(int, "bad").isErr
```

## Which structure for which access pattern

| You need | Reach for | Why not the neighbour |
|---|---|---|
| Stack, "build then reverse", shared tails | `cons_list` | O(1) at the front only |
| Undo and redo history (every version kept) | two `cons_list` stacks, past and future, plus the present value; an edit clears the future | a `seq` of versions copies on each edit |
| FIFO queue, each version used once | `bankers_queue` | amortized O(1); repeated pops from one old version re-pay the reversal |
| Both ends push and pop | `deque` | `bankers_queue` pops only the front |
| FIFO queue whose old versions are reused (backtracking search) | a local `seq` with a head index inside one routine, or `leftist_heap` keyed by an insertion counter (compiled in `details/leftist_heap.md`) | `bankers_queue` and `deque` are amortized and re-pay their rebuild on each reuse |
| Priority queue whose old versions are reused (undo), or merged often | `leftist_heap` (worst-case O(log n)) | `pairing_heap` is amortized: popping an old version again re-pays |
| Priority queue, each version used once | `pairing_heap` (usually fastest) or `leftist_heap` | |
| Priority queue, reason like binary addition | `binomial_heap` | worst-case O(log n) insert and merge |
| Ordered map or set, sorted iteration, no `remove` | `rb_tree` | `hamt` has no key order; with `remove`, see below |
| Unordered map with `remove`, large and updated functionally | `hamt` | `rb_tree` has deeper paths and no `remove` here |
| Ordered map that also needs `remove` | `hamt`, sorting keys when read (`toSortedSeq`, O(n log n), gives `(key, value)` pairs; the keys alone: `for (k, _) in m.toSortedSeq: result.add k`) | `rb_tree` here has no `remove` |
| Indexed sequence, push at the back, update by index | `pvector` | `seq` copies O(n) per version |
| Indexed stack (push, pop and index at the front) | `skew_list` | `cons_list` indexes in O(n) |
| Prefix search, autocompletion | `trie` | `hamt` finds whole keys only |
| Edit around a cursor (text, tree rewrite) | `zipper` | recursion from the root re-walks the path |
| Group membership with undo or backtracking | `union_find` | the array version with path compression loses old states |
| Range sum, min or gcd with point updates | `segment_tree` | a prefix-sum array cannot be updated cheaply |
| "Certainly absent" test with small memory | `bloom_filter` | exact sets cost more memory; no delete |
| Name data by its hash, detect corruption, or let one root digest identify a whole state and prove one part of it | `merkle_tree` (`CasStore`, `MerkleTree`) | a `hamt` of bytes does not notice rot; a hash of a flat list rehashes everything on each change |
| How a hash table works (probing, load factor), or an immutable snapshot with sorted iteration | `hash_table` | inside one routine `std/tables` is faster; old versions cheap: `hamt` |
| Priority queue inside one routine, heap sort, top-k | `std/heapqueue` in a local `var` (O(log n) per push and pop) | `binary_heap` shows how the heap works, but as a value each `push` and `pop` copies the array (O(n)), so k pops cost O(n·k); old versions reused: `leftist_heap` |
| Plain LIFO/FIFO inside one routine, next greater element (monotonic stack) | `stack_queue` | shared old versions: `cons_list`, `bankers_queue` |
| O(1) insert and remove next to a known node, LRU order | `linked_list` (arena of indices) | `cons_list` has no back links |
| Ordered set to learn BST insert, delete and traversal | `bst` (unbalanced; sorted input degrades to a chain) | balanced: `avl_tree`, `rb_tree`, `treap` |
| Ordered set with `delete` and guaranteed O(log n) | `avl_tree` | `rb_tree` here has no `remove` |
| Ordered set whose nodes hold many keys (disk-page model) | `b_tree` (insert only) | in memory, `avl_tree` is simpler |
| Ordered set with `split` and `merge` by key | `treap` (priorities from a seed, deterministic) | `avl_tree` has no split here |
| Ordered set where recently used keys are found faster | `splay_tree` | amortized; persistent reuse of old versions re-pays |
| Nearest point or points in a rectangle, fixed point set | `kd_tree` | high dimensions degrade to a scan |
| Prefix sums with point updates over integers, small memory | `fenwick_tree` | min or max: `segment_tree`; static min/max: `sparse_table` |
| Range min, max or gcd over a static array, O(1) per query | `sparse_table` | updates: `segment_tree` |
| Dense set of small integers, popcount, set algebra | `bit_vector` | sparse or large keys: `hamt` |
| Substring counts and longest repeat for short texts | `suffix_trie` (O(n²) nodes) | long texts need a suffix array or tree (not here) |

Each row names one structure; take that one.

Questions to ask in order:
1. Do old versions have to stay valid (is an older value read or popped again after a newer one was made)? If not, a local `var seq` or `Table` inside one routine is
   simpler and faster (ADR-NCK-0002 S5 allows local mutation).
2. Is access by position, by order, by key, or by prefix?
3. Where do elements enter and leave: front, back, both, by priority?
4. Is the usage ephemeral (each version used once) or truly persistent? Amortized bounds
   (`bankers_queue`, `deque`, `pairing_heap`) assume ephemeral use; worst-case structures
   (`leftist_heap`, `binomial_heap`, `skew_list`, `rb_tree`) hold under persistent use.

## Persistence and sharing in Nim

```nim
import nimcs/ds/cons_list

let base = fromSeq([2, 3])
let a = base.cons(1)
let b = base.cons(9)
doAssert a.tail.sharesNode(b.tail)    # one copy of [2, 3] in memory
doAssert base.toSeq == @[2, 3]         # base never changed
```

- **Wrap the `ref`.** A public type is a value `object` with a private `ref` node field; the empty
  value is `default(T)`. Callers never see `nil`.
- **Nodes are immutable.** A node is built once and never assigned to afterwards. Updating builds
  new nodes on the path and reuses the rest. A `seq` inside a node (for example the children of a
  HAMT node) is copied when changed, never mutated through a `ref` that another version reads.
- **ORC frees by reference counting.** A node disappears when the last version that reaches it is
  dropped, so sharing needs no extra bookkeeping. Cycles cannot form because nodes are immutable and
  only point downward.
- **Deep chains.** The default ORC destructor frees a chain recursively and overflows the stack on a
  list of a few hundred thousand nodes (measured: 5 x 10^5 crashed). `cons_list`, `pairing_heap` and
  `leftist_heap` therefore define an iterative `=destroy` that stops at nodes another version still
  shares (`isUniqueRef`); with it 5 x 10^7 cons cells and 5 x 10^6 heap nodes drop fine (release build,
  8 MB stack). Nim documents that `isUniqueRef` can change with the compiler version and optimiser, so
  `nim test` runs these drop tests (DS-CONSLIST-08, DS-PAIRINGHEAP-06, DS-LEFTISTHEAP-07) in debug and
  release builds; rerun it after upgrading Nim. A structure whose depth follows user data (a `trie` word, a `zipper` tree) still recurses:
  a trie word of 40,000 characters is fine in a release build, 60,000 crashes, and a debug build stops at
  about 2,000 (call depth limit).
- **Same names across modules.** The three heap modules export the same names; qualify `emptyHeap` and
  `fromSeq` with the module name when more than one is imported (`pairing_heap.emptyHeap[int]()`).
- **Iterate explicitly in generic code.** In a generic routine, write `for x in items(xs)` when `items`
  comes from another module; a bare `for x in xs` is resolved where the routine is instantiated and
  fails if the caller did not import that module.
- **A wrapper does not pass its imports on.** A module that wraps a structure (a task queue over a
  heap) must `export` the structure module, or its callers must import it too, before they can call
  `len`, `findMin` and the like on the wrapped value. Export it when the structure's type shows in
  an exported routine's signature or an exported field; when it sits only in a private field of a
  public object (below), there is nothing to export. A wrapper's pop returns
  `tuple[item: Option[T], rest: Wrapper]`: `none` and the empty wrapper when it is empty.
- **A different order is a wrapper element with its own `<`.** The heaps and trees compare with `<`,
  resolved where the generic is instantiated, so a `<` declared in your module before the first use
  is the one they call:

```nim
import std/options
import nimcs/ds/leftist_heap

type ByPriority = object      # highest priority first, then name ascending
  priority: int
  name: string

func `<`(a, b: ByPriority): bool {.raises: [].} =
  a.priority > b.priority or (a.priority == b.priority and a.name < b.name)

let h = emptyHeap[ByPriority]().insert(ByPriority(priority: 1, name: "a"))
  .insert(ByPriority(priority: 5, name: "b")).insert(ByPriority(priority: 5, name: "a"))
doAssert h.findMin.get.name == "a" and h.findMin.get.priority == 5
```

  A generic wrapper (an `LruCache[K, V]` over `LeftistHeap[Recency[K]]`) is instantiated in the
  module that uses it, and that module cannot see a private `<`: compiling it fails with a
  `type mismatch` inside the heap. Export the `<`; the element type can stay private. A wrapper
  that is not generic, like the task queue below, is instantiated in its own module, so its `<`
  stays private.

```nim
import std/options
import nimcs/ds/leftist_heap

type
  Recency[K] = object             # private; only its `<` is exported
    stamp: int
    key: K
  Oldest*[K] = object
    heap: LeftistHeap[Recency[K]]

func `<`*[K](a, b: Recency[K]): bool {.raises: [].} = a.stamp < b.stamp

func emptyOldest*[K](): Oldest[K] {.raises: [].} = Oldest[K](heap: emptyHeap[Recency[K]]())

func touch*[K](o: Oldest[K]; stamp: int; key: K): Oldest[K] {.raises: [].} =
  Oldest[K](heap: o.heap.insert(Recency[K](stamp: stamp, key: key)))

func oldest*[K](o: Oldest[K]): Option[K] {.raises: [].} =
  let top = o.heap.findMin
  if top.isSome: some(top.get.key) else: none(K)
```

  When the element type is fixed as a tuple, give the order to a private object that holds it, and
  keep the tuple in the public signature:

```nim
import std/options
import nimcs/ds/leftist_heap

type
  Task* = tuple[priority: int, name: string]
  Queued = object                 # carries the order; never leaves this module
    task: Task
  TaskQueue* = object
    heap: LeftistHeap[Queued]

func `<`(a, b: Queued): bool {.raises: [].} =   # highest priority first, then name
  a.task.priority > b.task.priority or
    (a.task.priority == b.task.priority and a.task.name < b.task.name)

func emptyTaskQueue*(): TaskQueue {.raises: [].} = TaskQueue(heap: emptyHeap[Queued]())

func push*(q: TaskQueue; t: Task): TaskQueue {.raises: [].} =
  TaskQueue(heap: q.heap.insert(Queued(task: t)))

func popHighest*(q: TaskQueue): tuple[item: Option[Task], rest: TaskQueue] {.raises: [].} =
  let top = q.heap.findMin
  if top.isNone: return (none(Task), q)
  (some(top.get.task), TaskQueue(heap: q.heap.deleteMin))

let q = emptyTaskQueue().push((1, "a")).push((5, "b")).push((5, "a"))
doAssert q.popHighest.item == some((5, "a"))
doAssert q.popHighest.rest.popHighest.item == some((5, "b"))
```
- **Build with a local `var`, return a value.** A routine may loop with a local `var` and return it;
  no caller sees the mutation. Never take `var` parameters in public routines.
- **Failure is a value.** `get(i)` is `Option[T]`; popping an empty structure returns the empty structure;
  construction that can be refused returns `Result[T, E]` with an enum error (`bloomFilter`).
- **Determinism.** `hamt` iterates in hash order, so it offers only `toSortedSeq`. `bloom_filter`
  uses `std/hashes`, which are stable for ints and strings, and a fixed salt, never a random seed.

## Laws every structure keeps

- **Persistence**: after `s2 = s.update(...)`, `s` still answers exactly as before.
- **Model equivalence**: any sequence of operations agrees with a simple `seq`, `Table` or sorted-`seq`
  model; the tests run random operation sequences against the model.
- **Invariant checks**: structures with an invariant (`rb_tree`, `leftist_heap`, `binomial_heap`,
  `skew_list`) expose `invariantsHold`, tested after every step.
- **Absence and emptiness are values**: no routine raises for an empty structure or an out-of-range index.

## Writing a new persistent structure here

1. Write the spec rows first (`DS-<NAME>-NN`, each law or visible behaviour), then one failing test per row
   (`test "DS-X-01 Given ..., when ..., then ...":` with a `# SPEC: DS-X-01` line above it).
2. Private immutable node type, public value wrapper, `func` + `{.raises: [].}` everywhere.
3. Add `invariantsHold` when there is an invariant, and test it after every operation in a property test.
4. Test against a model with random operations and test persistence explicitly (keep the old value,
   update, compare the old value).
5. Write the details page with the fixed sections and compiling `nim` blocks.

## Details pages

| Concept | Page | Module |
|---|---|---|
| Cons list | [details/cons_list.md](details/cons_list.md) | `src/nimcs/ds/cons_list.nim` |
| Banker's queue | [details/bankers_queue.md](details/bankers_queue.md) | `src/nimcs/ds/bankers_queue.nim` |
| Deque | [details/deque.md](details/deque.md) | `src/nimcs/ds/deque.nim` |
| Leftist heap | [details/leftist_heap.md](details/leftist_heap.md) | `src/nimcs/ds/leftist_heap.nim` |
| Pairing heap | [details/pairing_heap.md](details/pairing_heap.md) | `src/nimcs/ds/pairing_heap.nim` |
| Binomial heap | [details/binomial_heap.md](details/binomial_heap.md) | `src/nimcs/ds/binomial_heap.nim` |
| Red-black tree | [details/rb_tree.md](details/rb_tree.md) | `src/nimcs/ds/rb_tree.nim` |
| Skew-binary list | [details/skew_list.md](details/skew_list.md) | `src/nimcs/ds/skew_list.nim` |
| Persistent vector | [details/pvector.md](details/pvector.md) | `src/nimcs/ds/pvector.nim` |
| HAMT | [details/hamt.md](details/hamt.md) | `src/nimcs/ds/hamt.nim` |
| Trie | [details/trie.md](details/trie.md) | `src/nimcs/ds/trie.nim` |
| Zipper | [details/zipper.md](details/zipper.md) | `src/nimcs/ds/zipper.nim` |
| Persistent union-find | [details/union_find.md](details/union_find.md) | `src/nimcs/ds/union_find.nim` |
| Segment tree | [details/segment_tree.md](details/segment_tree.md) | `src/nimcs/ds/segment_tree.nim` |
| Bloom filter | [details/bloom_filter.md](details/bloom_filter.md) | `src/nimcs/ds/bloom_filter.nim` |
| Merkle tree and content-addressed store | [details/merkle_tree.md](details/merkle_tree.md) | `src/nimcs/ds/merkle_tree.nim` |
| Hash table | [details/hash_table.md](details/hash_table.md) | `src/nimcs/ds/hash_table.nim` |
| Binary heap | [details/binary_heap.md](details/binary_heap.md) | `src/nimcs/ds/binary_heap.nim` |
| Stack and queue | [details/stack_queue.md](details/stack_queue.md) | `src/nimcs/ds/stack_queue.nim` |
| Linked list (arena) | [details/linked_list.md](details/linked_list.md) | `src/nimcs/ds/linked_list.nim` |
| Binary search tree | [details/bst.md](details/bst.md) | `src/nimcs/ds/bst.nim` |
| AVL tree | [details/avl_tree.md](details/avl_tree.md) | `src/nimcs/ds/avl_tree.nim` |
| B-tree | [details/b_tree.md](details/b_tree.md) | `src/nimcs/ds/b_tree.nim` |
| Treap | [details/treap.md](details/treap.md) | `src/nimcs/ds/treap.nim` |
| Splay tree | [details/splay_tree.md](details/splay_tree.md) | `src/nimcs/ds/splay_tree.nim` |
| k-d tree | [details/kd_tree.md](details/kd_tree.md) | `src/nimcs/ds/kd_tree.nim` |
| Fenwick tree | [details/fenwick_tree.md](details/fenwick_tree.md) | `src/nimcs/ds/fenwick_tree.nim` |
| Sparse table | [details/sparse_table.md](details/sparse_table.md) | `src/nimcs/ds/sparse_table.nim` |
| Bit vector | [details/bit_vector.md](details/bit_vector.md) | `src/nimcs/ds/bit_vector.nim` |
| Suffix trie | [details/suffix_trie.md](details/suffix_trie.md) | `src/nimcs/ds/suffix_trie.nim` |

Specification rows: `docs/spec/ds.md`. Tests: `tests/test_ds_<concept>.nim`.
