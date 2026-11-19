---
name: nim-data-structures
description: >-
  Choose, write and review persistent (functional) data structures in Nim: cons list, banker's
  queue, deque, leftist/pairing/binomial heaps, red-black tree, skew-binary list, persistent
  vector, HAMT, trie, zipper, persistent union-find, segment tree and Bloom filter. Load it when
  a task needs a queue, priority queue, ordered or hash map, indexed sequence or prefix search
  whose old versions must stay valid, when an update must not mutate its argument, or when you
  must pick a structure for an access pattern. Every structure is a Nim 2.4 module with
  `func` routines, `Option`/`Result` failure and tested laws.
---

# Nim data structures: persistent and functional

Every structure in `src/nimcs/ds/` is **persistent**: an update returns a new value and the old
one stays valid. Unchanged parts are shared through `ref` to immutable nodes, so an update copies
only a path, not the whole structure. The modules follow the repository's style (ADR-NCK-0002):
public routines are `func` with `{.raises: [].}`, absence is `Option`, a failure with a reason is
`Result` (`nimcs/fp/result`), shapes are plain `object`s, nothing reads the clock, a random
source or a hash order. Each structure has a details page with its laws, complexity and pitfalls;
the laws are spec IDs (`docs/spec/ds.md`) checked by property tests.

Inside this repository, import the module (`import nimcs/<area>/<name>`). In another project the
modules are not a published package: copy the shape from the details page into your own file, or
add this repository's `src/` to the compiler path (`--path:"<repo>/src"`).

## Which structure for which access pattern

| You need | Reach for | Why not the neighbour |
|---|---|---|
| Stack, "build then reverse", shared tails | `cons_list` | O(1) at the front only |
| FIFO queue, each version used once | `bankers_queue` | amortized O(1); repeated pops from one old version re-pay the reversal |
| Both ends push and pop | `deque` | `bankers_queue` pops only the front |
| Priority queue, merge two queues often | `leftist_heap` (worst case), `pairing_heap` (usually fastest) | |
| Priority queue, reason like binary addition | `binomial_heap` | worst-case O(log n) insert and merge |
| Ordered map or set, sorted iteration | `rb_tree` | `hamt` has no key order |
| Unordered map with `remove`, large and updated functionally | `hamt` | `rb_tree` has deeper paths and no `remove` here |
| Ordered map that also needs `remove` | `hamt`, sorting keys when read (`toSortedSeq`, O(n log n)); or `rb_tree` rebuilt without the key (O(n)) when ordered reads dominate; when the mix is unknown, `hamt` | `rb_tree` here has no `remove` |
| Indexed sequence, push at the back, update by index | `pvector` | `seq` copies O(n) per version |
| Indexed stack (push, pop and index at the front) | `skew_list` | `cons_list` indexes in O(n) |
| Prefix search, autocompletion | `trie` | `hamt` finds whole keys only |
| Edit around a cursor (text, tree rewrite) | `zipper` | recursion from the root re-walks the path |
| Group membership with undo or backtracking | `union_find` | the array version with path compression loses old states |
| Range sum, min or gcd with point updates | `segment_tree` | a prefix-sum array cannot be updated cheaply |
| "Certainly absent" test with small memory | `bloom_filter` | exact sets cost more memory; no delete |

Questions to ask in order:
1. Do old versions have to stay valid? If not, a local `var seq` or `Table` inside one routine is
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
  `len`, `findMin` and the like on the wrapped value. A wrapper's pop returns
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

  When the element type is fixed as a tuple (`Task = tuple[name: string, priority: int]`), give the
  order to a wrapper object that holds it (`Queued = object` with a `task: Task` field and its own
  `<`). Push `Queued(task: t)` and return `.task` from the pop, so the public signature still speaks
  of `Task`.
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

Specification rows: `docs/spec/ds.md`. Tests: `tests/test_ds_<concept>.nim`.
