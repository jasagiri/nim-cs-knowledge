# Content addressing and the Merkle tree

## Intent
Name a blob by the hash of its bytes, and name a whole sequence of blocks by one root digest. A content-addressed store keeps one copy per content and notices a copy that no longer matches its name. A Merkle tree makes the root depend on every leaf, lets a holder of the root check a single leaf from a short audit path, and shares every unchanged subtree between versions: an update rebuilds one root-to-leaf path and nothing else.

A file sync service is the model. Each file's content is a blob named by its hash. Each generation (the state of the folder at one moment) is a tree over the lines `path, content name`, and the root digest identifies the whole generation: two devices compare one digest to learn whether they hold the same state, and a device that holds an old generation fetches only the blobs whose names it lacks.

## Use when / avoid when
- Use it when data has to be found by what it is (deduplication, caches, snapshots, backups), and when a copy that rotted or was swapped must be detected on read.
- Use it when one small value must stand for a large state and a part of that state must be provable on its own (sync, replication, audit logs, transparency logs).
- Use it when versions share almost everything and each version must stay valid (the same reasoning as `hamt` and `pvector`).
- Avoid it with a hash that is not collision-resistant whenever someone else can choose the content: `insecureFnv1a64` is for tests and examples. Pass SHA-256 (the `checksums` package, for example) through `newHasher`.
- Avoid it for a mutable name-to-value map that is not read back by hash: use `hamt`, which is cheaper.
- Avoid the tree for a set that is rewritten as a whole each time: hash the serialised bytes once with the store.

## Nim shape
Two sealed values, both persistent. `CasStore` is a `hamt` from `Digest` to bytes plus the `Hasher`; `put` returns a `Stored` tuple of the new store and the name, and `get` returns `Result[string, CasError]`: `ceMissing` when nothing is held under the name, `ceCorrupt` when what is held no longer hashes to the name. `MerkleTree` is a tree of immutable nodes (digest, leaf count, two children) plus the `Hasher`. Its shape depends only on the number of leaves: the left subtree holds the largest power of two below n leaves, so there is no duplicated filler leaf and no empty node. `Hasher` is a record of a name and a hash function over bytes; `newHasher` refuses a missing function or an empty name.

Content addressing first. Putting equal bytes twice keeps one copy, and a stored copy is checked on every read:

```nim
import nimcs/ds/merkle_tree

let h = insecureFnv1a64()               # tests and examples only; a real store passes SHA-256
let first = newCasStore(h).put("hello")
let again = first.store.put("hello")
doAssert again.digest == first.digest and again.store.len == 1
doAssert again.store.get(first.digest) == ok("hello", CasError)
doAssert newCasStore(h).get(first.digest) == err(string, ceMissing)

# the same name over bytes that rotted on disk
let rotten = loadUnverified(h, [(first.digest, "hellp")])
doAssert rotten.get(first.digest) == err(string, ceCorrupt)
```

The tree: root, audit path, update with sharing.

```nim
import std/options
import nimcs/ds/merkle_tree

let h = insecureFnv1a64()
let t = merkleTree(h, ["a", "b", "c", "d", "e"])
let path = t.prove(3).get                # the siblings from leaf 3 up to the root
doAssert verifyInclusion(h, t.root, t.len, 3, "d", path)
doAssert not verifyInclusion(h, t.root, t.len, 3, "x", path)     # wrong block
doAssert not verifyInclusion(h, t.root, t.len, 2, "d", path)     # wrong index

let u = t.update(3, "D").get
doAssert u.root != t.root                # any change to a leaf changes the root
doAssert u == merkleTree(h, ["a", "b", "c", "D", "e"])      # same as building from scratch
doAssert t.root == merkleTree(h, ["a", "b", "c", "d", "e"]).root   # the old tree is unchanged
doAssert rebuiltNodes(t, u) == 4         # leaf 3 and its three ancestors; the other 5 of 9 nodes are shared
doAssert u.nodeCount == 9
```

A generation of a synced folder: blobs go to the store, the tree is over the sorted `path, name` lines, and a one-file change is a one-leaf update.

```nim
import std/algorithm
import nimcs/ds/merkle_tree

type Generation = object
  store: CasStore
  tree: MerkleTree

func line(path: string; name: Digest): string =
  path & "\x00" & name.toHex            # the path may not contain NUL, so the line splits in one place

func snapshot(h: Hasher; base: CasStore; files: openArray[(string, string)]): Generation =
  var store = base                               # blobs already held are kept, not copied again
  var lines: seq[string]
  for (path, content) in sorted(files):          # a fixed order, or equal states get different roots
    let stored = store.put(content)
    store = stored.store
    lines.add line(path, stored.digest)
  Generation(store: store, tree: merkleTree(h, lines))

let h = insecureFnv1a64()
let monday = snapshot(h, newCasStore(h), [("notes.txt", "milk"), ("todo.txt", "write"), ("a/b.txt", "x")])
let sameAgain = snapshot(h, newCasStore(h), [("a/b.txt", "x"), ("todo.txt", "write"), ("notes.txt", "milk")])
doAssert monday.tree.root == sameAgain.tree.root       # one digest says "same state"
let tuesday = snapshot(h, monday.store, [("notes.txt", "milk, eggs"), ("todo.txt", "write"), ("a/b.txt", "x")])
doAssert tuesday.tree.root != monday.tree.root
doAssert tuesday.store.len == 4                        # Monday's three blobs and the one edited content
```

The main module is `src/nimcs/ds/merkle_tree.nim`.

## Public API

Every exported symbol of `src/nimcs/ds/merkle_tree.nim`, generated by `nim apiSections` (the
tests fail when it drifts). `import nimcs/ds/merkle_tree` brings these names. A type they use from
another module (`Option`, `Result`, `Graph`) needs that module's import too, as in the example
above. A field marked `*` is readable outside the module; a type shown without fields is opaque,
built and read only through the functions.

```text
type Digest = distinct string
type HashProc = proc (data: string): string {.noSideEffect, raises: [].}
type HasherError = enum
  heNoProc, heNoName
type Hasher {.requiresInit.} = object
type CasError = enum
  ceMissing, ceCorrupt
type CasStore {.requiresInit.} = object
type Stored = tuple[store: CasStore, digest: Digest]
type MerkleTree {.requiresInit.} = object
type AuditPath = seq[Digest]
func `==`(a, b: Digest): bool
func `<`(a, b: Digest): bool
func hash(d: Digest): Hash
func asDigest(raw: string): Digest
func toBytes(d: Digest): string
func toHex(d: Digest): string
func `$`(d: Digest): string
func newHasher(name: string; digest: HashProc): Result[Hasher, HasherError]
func name(h: Hasher): string
func insecureFnv1a64(): Hasher
func addressOf(h: Hasher; data: string): Digest
func hashLeaf(h: Hasher; blk: string): Digest
func hashInner(h: Hasher; left, right: Digest): Digest
func emptyRoot(h: Hasher): Digest
func newCasStore(h: Hasher): CasStore
func loadUnverified(h: Hasher; entries: openArray[(Digest, string)]): CasStore
func len(s: CasStore): int
func contains(s: CasStore; d: Digest): bool
func put(s: CasStore; data: string): Stored
func get(s: CasStore; d: Digest): Result[string, CasError]
func merkleTree(h: Hasher; blocks: openArray[string]): MerkleTree
func len(t: MerkleTree): int
func root(t: MerkleTree): Digest
func nodeCount(t: MerkleTree): int
func leafDigest(t: MerkleTree; i: int): Option[Digest]
func update(t: MerkleTree; i: int; blk: string): Option[MerkleTree]
func append(t: MerkleTree; blk: string): MerkleTree
func prove(t: MerkleTree; i: int): Option[AuditPath]
func verifyInclusion(h: Hasher; root: Digest; count, index: int; blk: string; path: AuditPath): bool
func `==`(a, b: MerkleTree): bool
func rebuiltNodes(before, after: MerkleTree): int
```

## Laws and invariants
- Put then get returns the bytes, and the name is the hash of the bytes (DS-MERKLE-01).
- Putting the same bytes again keeps one copy, and the old store is unchanged (DS-MERKLE-02).
- A missing name is `ceMissing`; a copy that no longer hashes to its name is `ceCorrupt` (DS-MERKLE-03).
- The audit path of every leaf verifies against the root, and its length is at most ceil(log2 n) (DS-MERKLE-04).
- A proof fails for a wrong block, a wrong index, a wrong root, or a path that is shorter, longer or altered (DS-MERKLE-05).
- Changing, adding or dropping a leaf changes the root; the same blocks give the same root (DS-MERKLE-06). This holds up to a collision of the hash: with the test hash, a pair of different inputs collides with probability 2^-64, and with a hash that collides, the law does not hold (DS-MERKLE-11).
- An updated or appended tree equals the tree built from scratch on the new blocks, node by node, and the old tree is unchanged (DS-MERKLE-07).
- An update rebuilds at most ceil(log2 n) + 1 nodes of the 2n - 1; an append rebuilds the right edge; every other node is the same memory as before (DS-MERKLE-08).
- The empty tree has the root `emptyRoot`, no proofs and no updates; a one-leaf tree has the leaf digest as its root and an empty path (DS-MERKLE-09).
- The two digests of an inner node offered as one leaf block do not reproduce the root (DS-MERKLE-10).
- The root of `[a, b, c]` differs from that of `[a, b, c, c]` (DS-MERKLE-12).
- `newHasher` refuses a missing function and an empty name (DS-MERKLE-13).

## Complexity
| Operation | Time | Space |
|---|---|---|
| `put`, `get` (store) | O(log32 n) in the number of blobs, plus one hash of the bytes | O(log32 n) new nodes per put |
| `merkleTree` | O(n) hashes | 2n - 1 nodes |
| `update`, `append` | O(log n) hashes | O(log n) new nodes, the rest shared |
| `prove` | O(log n) | O(log n) digests |
| `verifyInclusion` | O(log n) hashes | O(log n) |
| `root`, `len`, `nodeCount` | O(1) | O(1) |
| `leafDigest` | O(log n) | O(1) |
| `rebuiltNodes` | O(n log n), a measuring tool | O(n) |

## Pitfalls
Three mistakes that look harmless. No prefix between leaves and inner nodes lets an attacker present the two child digests of an inner node as a single leaf: the one-leaf tree over `digest(left) & digest(right)` then has the same root as the two-leaf tree (a second-preimage attack on the tree), and proofs about data that was never a leaf verify. Duplicating the last node of an odd level makes `[a, b, c]` and `[a, b, c, c]` share a root; Bitcoin's block tree did this, and CVE-2012-2459 was the resulting trick of making a block with repeated transactions look equal to the valid one. Trusting a name without hashing what was read means a flipped bit or a substituted file is served as the one asked for.

```nim bad
import std/[hashes, tables]

type Store = Table[string, string]

func digest(data: string): string =
  $hash(data)                                  # also: a 64-bit toy hash, see below

func leaf(blk: string): string = digest(blk)                  # no prefix: same function as inner
func inner(l, r: string): string = digest(l & r)

func root(level: seq[string]): string =
  var cur = level
  while cur.len > 1:
    if cur.len mod 2 == 1: cur.add cur[^1]     # odd level: duplicate the last node
    var next: seq[string]
    for i in countup(0, cur.len - 1, 2): next.add inner(cur[i], cur[i + 1])
    cur = next
  cur[0]

func fetch(store: Store; name: string): string =
  store[name]                                  # whatever is stored is returned, intact or not
```

Fix: prefix leaves and inner nodes differently, split the sequence by its length instead of padding (`merkleTree` does), and hash what `get` read before returning it (`CasStore.get` does).

```nim
import nimcs/ds/merkle_tree

let h = insecureFnv1a64()
let two = merkleTree(h, ["left", "right"])
let forged = merkleTree(h, [hashLeaf(h, "left").toBytes & hashLeaf(h, "right").toBytes])
doAssert forged.root != two.root
doAssert merkleTree(h, ["a", "b", "c"]).root != merkleTree(h, ["a", "b", "c", "c"]).root
```

The hash is the other half of the guarantee, and everything above is only as strong as it. With a collision-resistant hash, a reader who holds a name or a root can reject any other content. With a hash that has collisions, the attacker who can make two blocks share a digest asks you to store the harmless one, then substitutes the other: the store, the proof and the root all accept it, as DS-MERKLE-11 shows with a toy hash. The shipped FNV-1a is that kind of hash (it was designed for hash tables, not adversaries). Pass SHA-256 or another collision-resistant function through `newHasher`; it takes any function from bytes to raw digest bytes, so the package needs no dependency of its own.

```nim
import nimcs/ds/merkle_tree

# A hasher needs a function; `newHasher` says so instead of failing on the first put.
let noFunction = newHasher("sha-256", nil)
doAssert noFunction.isErr and noFunction.error == heNoProc
doAssert insecureFnv1a64().name == "insecure-fnv1a64"      # the shipped hash says what it is
```

Two smaller points. The root does not authenticate a block's position by itself unless `verifyInclusion` is given the leaf count from a trusted source (a signed root with its size, for example); and a proof for index i only shows that a block equal to the one given sits at i, so two equal blocks are interchangeable. The store names blobs by the bare hash of their bytes: if one store also holds tree nodes or other kinds of object, tag the kinds (git hashes a header such as the kind and the length before the bytes) so that a blob cannot be passed off as a node.

## Related
`hamt.md` (the persistent map under `CasStore`, and the same path-copying idea), `pvector.md` (a persistent sequence by index; the tree here is a sequence addressed by hash), `idempotent_command.md` and `event_sourcing.md` in the design patterns (a put is idempotent by construction, which is why a retried upload is safe; an event log whose root digest is the audit trail), `atomic_publish.md` in the design patterns (writing a blob under its hash so a reader never sees it half written).

## Sources

Catalog IDs (catalog/sources.jsonl) of sources that explain this concept, each under a licence that allows commercial use:

- `910b65056f3e5195` Merkle tree (Wikipedia): hash tree, root hash, inclusion proofs
- `361f12a35168f674` Content-addressable storage (Wikipedia): addressing data by its content hash
