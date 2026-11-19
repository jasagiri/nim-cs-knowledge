# Bloom filter

## Intent
A compact set that answers "definitely not present" or "probably present". It never forgets a key that was added (no false negatives) but may report keys that were never added (false positives). Adding returns a new filter, so the structure has value semantics.

## Use when / avoid when
- Use it to skip an expensive lookup (disk, network) for keys that are certainly absent.
- Use it when memory matters more than exactness and a small false-positive rate is acceptable.
- Avoid it when a false positive is harmful or when you must delete keys: a Bloom filter cannot delete. Use `hamt` or `rb_tree` for exact membership.
- Avoid copying it in a hot loop: every `add` copies the bit array. Build with a local `var` inside one routine or merge filters instead.

## Nim shape
`BloomFilter` holds a `seq[uint64]` bit array, the bit count, the hash count and a counter of adds. Construction validates its arguments and returns `Result[BloomFilter, BloomError]` (an enum: `beNoBits`, `beNoHashes`, `beShapeMismatch`). The `k` positions of a key come from two deterministic hashes of `(salt, key)` pairs combined as `h1 + i * stride` (double hashing); the stride is the second hash made coprime to the bit count, so the first min(k, bits) positions of a key are distinct for every bit count (an odd stride would only guarantee that for powers of two). `setBits` counts the 1 bits. `merge` ORs the bit arrays of two filters of equal shape.

```nim
import nimcs/fp/result
import nimcs/ds/bloom_filter

let made = bloomFilter(4096, 3)
doAssert made.isOk
let empty = made.value
let f = empty.add("apple").add("pear")
doAssert f.mightContain("apple")
doAssert not empty.mightContain("apple")   # the old filter is unchanged
let other = empty.add("fig")
let merged = f.merge(other)
doAssert merged.isOk
doAssert merged.value.mightContain("fig")
doAssert bloomFilter(0, 3) == err(BloomFilter, beNoBits)
```

The main module is `src/nimcs/ds/bloom_filter.nim`; it uses `nimcs/fp/result`.

## Laws and invariants
- Every added key is found: no false negatives (DS-BLOOM-01).
- Adding a key twice gives the same bit array as adding it once (DS-BLOOM-02).
- `add` leaves the old filter unchanged (DS-BLOOM-03).
- `merge` of equal-shape filters has the same bits as one filter that received all the keys, and is commutative (DS-BLOOM-04).
- Invalid sizes and mismatched shapes are error values with a reason (DS-BLOOM-05).
- A well-sized filter reports few false positives on absent keys (DS-BLOOM-06).
- For any bit count (powers of two or not) one key sets exactly min(hashes, bits) distinct bits (DS-BLOOM-07).

## Complexity
| Operation | Time | Space |
|---|---|---|
| `add` | O(k + bits / 64) because the array is copied | O(bits / 64) new |
| `mightContain` | O(k) | O(1) |
| `merge` | O(bits / 64) | O(bits / 64) new |

The false-positive rate after n adds is about (1 - e^(-k n / m))^k for m bits.

## Pitfalls
Using one hash with an unrelated seed per probe makes `k` hash computations; and using a random seed makes results differ between runs.

```nim bad
import std/[hashes, random]

func positions(key: string; k, bits: int): seq[int] =
  for i in 0 ..< k:
    result.add abs(hash(key) + rand(1000)) mod bits   # random: not reproducible, not stable
```

Derive all positions from two deterministic hashes, as the module does.

```nim
import nimcs/fp/result
import nimcs/ds/bloom_filter

let f = bloomFilter(2048, 5).value.add(42)
doAssert f.mightContain(42)
doAssert f.hashes == 5
```

## Related
`hamt.nim`, `rb_tree.nim`, `trie.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `7508271bf7980bd3` Data Structures
- `5ea7cdc2c5670fd7` Data Structures and Algorithms
