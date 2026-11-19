# Hash array mapped trie (HAMT)

## Intent
A persistent unordered map. The key's hash is consumed five bits at a time; each node stores a 32-bit bitmap of used slots and only the used slots, so nodes stay small. An update copies one path and shares the rest.

## Use when / avoid when
- Use it for large maps that are updated functionally and need only lookup, insert and remove.
- Use it when old versions of the map must stay valid (snapshots, transactions, backtracking).
- Avoid it when you need ordered traversal or range queries: use `rb_tree`.
- Avoid it when keys have no cheap, well-spread hash.

## Nim shape
`Hamt[K, V]` has a root node and a size. A `Node` has a `bitmap: uint32` and `slots: seq[Slot]`; the slot for chunk `idx` sits at `popcount(bitmap and (bit(idx) - 1))`. A `Slot` is an object variant over `SlotKind` (a pair, a child node, or a bucket of pairs whose hashes are identical down to the last level); every `case` over it is exhaustive. The hash is `hash(key)` from `std/hashes`; for your own key type define `hash` and `==`. Iteration order depends on the hash, so the module has no unordered iterator: `toSortedSeq` sorts by key (the key type needs `<`).

```nim
import std/options
import nimcs/ds/hamt

let m = emptyHamt[string, int]().put("b", 2).put("a", 1).put("c", 3)
doAssert m.get("a") == some(1)
doAssert m.contains("c")
let r = m.remove("b")
doAssert r.get("b").isNone
doAssert m.get("b") == some(2)         # the old map is unchanged
doAssert m.toSortedSeq == @[("a", 1), ("b", 2), ("c", 3)]
```

The main module is `src/nimcs/ds/hamt.nim`.

## Laws and invariants
- Lookup returns the last value put for each key, none for absent keys, with the right size (DS-HAMT-01).
- `remove` deletes the key, keeps all others and lowers the size by one when the key was present (DS-HAMT-02).
- `put` and `remove` leave the old map unchanged (DS-HAMT-03).
- `toSortedSeq` is sorted by key and does not depend on insertion order (DS-HAMT-04).
- Keys with identical or colliding hashes stay distinct and reachable through put, get and remove (DS-HAMT-05).
- The empty map has no keys and `remove` of an absent key changes nothing (DS-HAMT-06).
- String keys behave like a table model (DS-HAMT-07).

## Complexity
| Operation | Time | Space |
|---|---|---|
| `get`, `contains` | O(log32 n), at most 13 levels | O(1) |
| `put`, `remove` | O(log32 n) levels, each copying up to 32 slots | O(log32 n) new nodes |
| `toSortedSeq` | O(n log n) | O(n) |

## Pitfalls
Exposing the trie's own order lets the hash order leak into output.

```nim bad
import std/hashes

func order(keys: seq[string]): seq[string] =
  # "Iterate the map and print": the order follows hash bits, so it changes when the
  # hash function or the insertion history changes.
  var buckets = newSeq[seq[string]](8)
  for k in keys:
    buckets[hash(k) and 7].add k
  for b in buckets:
    result.add b
```

Sort by key at the edge, as `toSortedSeq` does.

```nim
import nimcs/ds/hamt

let m = fromPairs([("z", 1), ("a", 2)])
doAssert m.toSortedSeq == @[("a", 2), ("z", 1)]
```

## Related
`rb_tree.nim`, `trie.nim`, `pvector.nim`, `bloom_filter.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `7508271bf7980bd3` Data Structures
