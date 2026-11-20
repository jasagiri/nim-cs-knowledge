## Content addressing and the Merkle tree: persistent values whose names are their hashes.
##
## `CasStore` is a content-addressed store: the name of a blob is the hash of its bytes, `put` returns
## a new store and that name, the same bytes put twice keep one copy, and `get` hashes what it found
## again, so a copy that rotted on disk is reported (`ceCorrupt`) instead of returned. `MerkleTree`
## is a tree of digests over a sequence of blocks: its root covers every leaf, an audit path
## proves one leaf against the root, and an update or an append rebuilds one path of O(log n) nodes
## and shares every other node with the old tree.
##
## The hash is a parameter (`Hasher`). The module ships one hash only, `insecureFnv1a64`, whose name
## says what it is: it has no resistance to collisions, so anyone can build two blocks with one
## digest and substitute one for the other. A store or tree that faces untrusted data needs a
## collision-resistant hash such as SHA-256, passed in through `newHasher`.
##
## Leaves and inner nodes are hashed under different prefix bytes (domain separation), so an inner
## node's two digests can never pass as a leaf block. The shape of the tree depends only on the
## number of leaves (the left subtree is the largest power of two below n), so no leaf is ever
## duplicated to fill a level.

import std/[hashes, options]
import nimcs/fp/result
import nimcs/ds/hamt
export result

type
  Digest* = distinct string
    ## The raw bytes of a hash result. The length is the hasher's.
  HashProc* = proc(data: string): string {.noSideEffect, raises: [].}
  HasherError* = enum
    heNoProc, heNoName
  Hasher* {.requiresInit.} = object
    hname: string
    fn: HashProc

  CasError* = enum
    ceMissing, ceCorrupt
  CasStore* {.requiresInit.} = object
    hasher: Hasher
    blobs: Hamt[Digest, string]
  Stored* = tuple[store: CasStore, digest: Digest]

  Node = ref object
    digest: Digest
    count: int            ## leaves below this node
    left, right: Node     ## both nil for a leaf, both set for an inner node
  MerkleTree* {.requiresInit.} = object
    hasher: Hasher
    top: Node             ## nil when there are no leaves
  AuditPath* = seq[Digest]
    ## The digests of the siblings met on the way from a leaf up to the root, bottom first.

# --- digests and hashers -------------------------------------------------------------------------

func `==`*(a, b: Digest): bool {.borrow.}
func `<`*(a, b: Digest): bool {.borrow.}
func hash*(d: Digest): Hash {.borrow.}

func asDigest*(raw: string): Digest {.raises: [].} =
  ## Wraps the raw bytes a hash function returned.
  Digest(raw)

func toBytes*(d: Digest): string {.raises: [].} =
  string(d)

func toHex*(d: Digest): string {.raises: [].} =
  const hexDigits = "0123456789abcdef"
  for c in string(d):
    result.add hexDigits[ord(c) shr 4]
    result.add hexDigits[ord(c) and 15]

func `$`*(d: Digest): string {.raises: [].} =
  toHex(d)

func newHasher*(name: string; digest: HashProc): Result[Hasher, HasherError] {.raises: [].} =
  ## A hasher from a hash function over bytes (for example SHA-256 returning its 32 raw bytes) and
  ## the name that identifies it in logs.
  if digest.isNil: err(Hasher, heNoProc)
  elif name.len == 0: err(Hasher, heNoName)
  else: ok(Hasher(hname: name, fn: digest), HasherError)

func name*(h: Hasher): string {.raises: [].} =
  h.hname

func fnv1a64Bytes(data: string): string {.raises: [].} =
  var h = 0xcbf29ce484222325'u64
  for c in data:
    h = (h xor uint64(ord(c))) * 0x100000001b3'u64
  for i in countdown(7, 0):
    result.add char((h shr (i * 8)) and 0xff'u64)

func insecureFnv1a64*(): Hasher {.raises: [].} =
  ## FNV-1a with 64 bits, big-endian. Fast and well spread, and trivial to attack: use it for
  ## tests and examples only, never where someone can choose the content.
  Hasher(hname: "insecure-fnv1a64", fn: fnv1a64Bytes)

func addressOf*(h: Hasher; data: string): Digest {.raises: [].} =
  ## The content address of `data`: its hash, with no prefix.
  Digest(h.fn(data))

func hashLeaf*(h: Hasher; blk: string): Digest {.raises: [].} =
  ## A leaf digest: the hash of a 0x00 byte followed by the block.
  Digest(h.fn("\x00" & blk))

func hashInner*(h: Hasher; left, right: Digest): Digest {.raises: [].} =
  ## An inner digest: the hash of a 0x01 byte followed by the two child digests.
  Digest(h.fn("\x01" & string(left) & string(right)))

func emptyRoot*(h: Hasher): Digest {.raises: [].} =
  ## The root of a tree with no leaves: the hash of the empty input, which no prefixed input equals.
  addressOf(h, "")

# --- content-addressed store -----------------------------------------------------------------------

func newCasStore*(h: Hasher): CasStore {.raises: [].} =
  CasStore(hasher: h, blobs: emptyHamt[Digest, string]())

func loadUnverified*(h: Hasher; entries: openArray[(Digest, string)]): CasStore {.raises: [].} =
  ## A store holding the given name and bytes pairs as read from outside (a disk, a network) without
  ## checking them; `get` checks on every read.
  var blobs = emptyHamt[Digest, string]()
  for (d, bytes) in entries:
    blobs = blobs.put(d, bytes)
  CasStore(hasher: h, blobs: blobs)

func len*(s: CasStore): int {.raises: [].} =
  ## Number of names held (one per distinct content).
  s.blobs.len

func contains*(s: CasStore; d: Digest): bool {.raises: [].} =
  ## Whether a copy is held under the name `d`; it does not check that the copy is intact.
  s.blobs.contains(d)

func put*(s: CasStore; data: string): Stored {.raises: [].} =
  ## The store holding `data` and the name it is held under. Putting equal bytes again changes nothing.
  let d = addressOf(s.hasher, data)
  (store: CasStore(hasher: s.hasher, blobs: s.blobs.put(d, data)), digest: d)

func get*(s: CasStore; d: Digest): Result[string, CasError] {.raises: [].} =
  ## The bytes named `d`, only if they still hash to `d`.
  let found = s.blobs.get(d)
  if found.isNone: err(string, ceMissing)
  elif addressOf(s.hasher, found.get) != d: err(string, ceCorrupt)
  else: ok(found.get, CasError)

# --- Merkle tree -----------------------------------------------------------------------------------

func splitPoint(n: int): int =
  ## The largest power of two below `n`, for n >= 2: the size of the left subtree.
  result = 1
  while result * 2 < n: result *= 2

func leafNode(h: Hasher; blk: string): Node =
  Node(digest: hashLeaf(h, blk), count: 1)

func joinNodes(h: Hasher; l, r: Node): Node =
  Node(digest: hashInner(h, l.digest, r.digest), count: l.count + r.count, left: l, right: r)

func buildNode(h: Hasher; blocks: openArray[string]; lo, n: int): Node =
  if n == 1: leafNode(h, blocks[lo])
  else:
    let k = splitPoint(n)
    joinNodes(h, buildNode(h, blocks, lo, k), buildNode(h, blocks, lo + k, n - k))

func merkleTree*(h: Hasher; blocks: openArray[string]): MerkleTree {.raises: [].} =
  ## The tree over `blocks` in order; O(n) hashes.
  MerkleTree(hasher: h, top: if blocks.len == 0: nil else: buildNode(h, blocks, 0, blocks.len))

func len*(t: MerkleTree): int {.raises: [].} =
  ## Number of leaves.
  if t.top.isNil: 0 else: t.top.count

func root*(t: MerkleTree): Digest {.raises: [].} =
  ## The digest that covers every leaf; `emptyRoot` for a tree with no leaves.
  if t.top.isNil: emptyRoot(t.hasher) else: t.top.digest

func nodeCount*(t: MerkleTree): int {.raises: [].} =
  ## Leaves plus inner nodes: 2n - 1 for n >= 1.
  if t.top.isNil: 0 else: 2 * t.top.count - 1

func leafDigest*(t: MerkleTree; i: int): Option[Digest] {.raises: [].} =
  if i < 0 or i >= t.len: return none(Digest)
  var n = t.top
  var at = i
  while not n.left.isNil:
    let k = n.left.count
    if at < k: n = n.left
    else:
      at -= k
      n = n.right
  some(n.digest)

func updateNode(h: Hasher; n: Node; i: int; blk: string): Node =
  if n.left.isNil: leafNode(h, blk)
  else:
    let k = n.left.count
    if i < k: joinNodes(h, updateNode(h, n.left, i, blk), n.right)
    else: joinNodes(h, n.left, updateNode(h, n.right, i - k, blk))

func update*(t: MerkleTree; i: int; blk: string): Option[MerkleTree] {.raises: [].} =
  ## The tree with leaf `i` replaced, rebuilding the path from that leaf to the root; none when `i`
  ## is out of range.
  if i < 0 or i >= t.len: none(MerkleTree)
  else: some(MerkleTree(hasher: t.hasher, top: updateNode(t.hasher, t.top, i, blk)))

func appendNode(h: Hasher; n: Node; blk: string): Node =
  if n.isNil: leafNode(h, blk)
  elif n.left.isNil: joinNodes(h, n, leafNode(h, blk))
  elif n.count == 2 * n.left.count: joinNodes(h, n, leafNode(h, blk))    # full: the old tree becomes the left child
  else: joinNodes(h, n.left, appendNode(h, n.right, blk))

func append*(t: MerkleTree; blk: string): MerkleTree {.raises: [].} =
  ## The tree with one more leaf at the end; rebuilds the right edge only.
  MerkleTree(hasher: t.hasher, top: appendNode(t.hasher, t.top, blk))

func proveNode(n: Node; i: int; topDown: var seq[Digest]) =
  if n.left.isNil: return
  let k = n.left.count
  if i < k:
    topDown.add n.right.digest
    proveNode(n.left, i, topDown)
  else:
    topDown.add n.left.digest
    proveNode(n.right, i - k, topDown)

func prove*(t: MerkleTree; i: int): Option[AuditPath] {.raises: [].} =
  ## The audit path of leaf `i`, bottom first; none when `i` is out of range.
  if i < 0 or i >= t.len: return none(AuditPath)
  var topDown: seq[Digest]
  proveNode(t.top, i, topDown)
  var path: AuditPath
  for j in countdown(topDown.len - 1, 0):
    path.add topDown[j]
  some(path)

func verifyInclusion*(h: Hasher; root: Digest; count, index: int; blk: string;
    path: AuditPath): bool {.raises: [].} =
  ## Whether `blk` is leaf `index` of a tree of `count` leaves whose root is `root`. The verifier
  ## needs only the root (from a source it trusts), the leaf count and the path.
  if index < 0 or index >= count: return false
  var siblingLeft: seq[bool]      # top down: is the sibling at this level the left child?
  var at = index
  var n = count
  while n > 1:
    let k = splitPoint(n)
    if at < k:
      siblingLeft.add false
      n = k
    else:
      siblingLeft.add true
      at -= k
      n -= k
  if siblingLeft.len != path.len: return false
  var cur = hashLeaf(h, blk)
  for j in 0 ..< path.len:
    cur =
      if siblingLeft[siblingLeft.len - 1 - j]: hashInner(h, path[j], cur)
      else: hashInner(h, cur, path[j])
  cur == root

func sameNodes(a, b: Node): bool =
  if a == b: true             # the same node, or both nil
  elif a.isNil or b.isNil: false
  elif a.count != b.count or a.digest != b.digest: false
  elif a.left.isNil: b.left.isNil
  else: not b.left.isNil and sameNodes(a.left, b.left) and sameNodes(a.right, b.right)

func `==`*(a, b: MerkleTree): bool {.raises: [].} =
  ## Same shape and same digest at every node. The hashers are not compared (a closure has no equality).
  sameNodes(a.top, b.top)

func collectNodes(n: Node; into: var seq[Node]) =
  if n.isNil: return
  into.add n
  collectNodes(n.left, into)
  collectNodes(n.right, into)

func isMember(n: Node; nodes: seq[Node]): bool =
  ## Identity, not equality of content: a ref has no `hash` in the standard library, so a set of
  ## nodes is not available and a scan does the job.
  for m in nodes:
    if m == n: return true
  false

func countUnseen(n: Node; seen: seq[Node]): int =
  if n.isNil or n.isMember(seen): 0
  else: 1 + countUnseen(n.left, seen) + countUnseen(n.right, seen)

func rebuiltNodes*(before, after: MerkleTree): int {.raises: [].} =
  ## Number of nodes of `after` that are not nodes of `before` (the other nodes are the same memory
  ## in both). An update of one leaf of n leaves gives at most ceil(log2 n) + 1. O(n log n): a
  ## measuring tool, not for hot paths.
  var seen: seq[Node]
  collectNodes(before.top, seen)
  countUnseen(after.top, seen)
