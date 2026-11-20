import std/[unittest, options]
import propcheck
import nimcs/ds/merkle_tree

# The test hash is the module's non-cryptographic FNV-1a 64. A property such as "the root changes when a
# leaf changes" holds only up to a collision of that hash: 2^-64 per pair of generated inputs, and the
# generators are deterministic, so a failure would be reproducible and not flaky. A real store uses a
# collision-resistant hash; the page says why (DS-MERKLE-11).

let fnv = insecureFnv1a64()

func distinctBlocks(xs: seq[string]): seq[string] =
  ## Blocks that differ from each other, so a proof for index i cannot also fit index j.
  for i, x in xs: result.add x & "#" & $i

func ceilLog2(n: int): int =
  while (1 shl result) < n: inc result

func lengthOnly(): Hasher =
  ## A deliberately weak hash: the digest is the length of the data, so every block of one length collides.
  let r = newHasher("length-only", proc(data: string): string {.noSideEffect, raises: [].} = $data.len)
  doAssert r.isOk
  r.value

suite "merkle_tree":
  # SPEC: DS-MERKLE-01
  test "DS-MERKLE-01 Given any bytes, when put and read back, then get returns the bytes and the name is their hash":
    let outcome = check(seqOf(stringOf("ab\0", 0, 12), 0, 30),
      proc(bs: seq[string]): bool {.raises: [CatchableError].} =
        var s = newCasStore(fnv)
        for b in bs:
          let p = s.put(b)
          if p.digest != addressOf(fnv, b): return false
          s = p.store
        for b in bs:
          if s.get(addressOf(fnv, b)) != ok(b, CasError): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-MERKLE-02
  test "DS-MERKLE-02 Given a store, when the same bytes are put twice, then one copy is kept and the old store is unchanged":
    let outcome = check(seqOf(stringOf("ab", 0, 6), 0, 30),
      proc(bs: seq[string]): bool {.raises: [CatchableError].} =
        var s = newCasStore(fnv)
        for b in bs: s = s.put(b).store
        for b in bs:
          let again = s.put(b)
          if again.store.len != s.len or again.digest != addressOf(fnv, b): return false
          if again.store.put(b).store.len != s.len: return false
        let before = s.len
        let grown = s.put("never put before: \xff")
        grown.store.len == before + 1 and s.len == before and not s.contains(grown.digest))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-MERKLE-03
  test "DS-MERKLE-03 Given a missing name or a stored copy that no longer hashes to its name, when reading, then get says missing or corrupt":
    let outcome = check(pair(stringOf("ab", 0, 8), stringOf("ab", 0, 8)),
      proc(a: (string, string)): bool {.raises: [CatchableError].} =
        let empty = newCasStore(fnv)
        if empty.get(addressOf(fnv, a[0])) != err(string, ceMissing): return false
        if a[0] == a[1]: return true
        # bit rot: the bytes found under the name of a[0] are a[1]
        let rotten = loadUnverified(fnv, [(addressOf(fnv, a[0]), a[1])])
        rotten.get(addressOf(fnv, a[0])) == err(string, ceCorrupt))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-MERKLE-04
  test "DS-MERKLE-04 Given any blocks, when proving each leaf, then the proof verifies against the root":
    let outcome = check(seqOf(stringOf("abc", 0, 6), 1, 40),
      proc(raw: seq[string]): bool {.raises: [CatchableError].} =
        let bs = distinctBlocks(raw)
        let t = merkleTree(fnv, bs)
        for i, b in bs:
          let p = t.prove(i)
          if p.isNone or not verifyInclusion(fnv, t.root, t.len, i, b, p.get): return false
          if p.get.len > ceilLog2(bs.len): return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-MERKLE-05
  test "DS-MERKLE-05 Given a valid proof, when the block, index, root or path is wrong, then verification fails":
    let outcome = check(pair(seqOf(stringOf("abc", 0, 6), 2, 40), intIn(0, 1000)),
      proc(a: (seq[string], int)): bool {.raises: [CatchableError].} =
        let bs = distinctBlocks(a[0])
        let t = merkleTree(fnv, bs)
        let i = a[1] mod bs.len
        let j = (i + 1 + a[1] mod (bs.len - 1)) mod bs.len     # another valid index
        let path = t.prove(i).get
        if not verifyInclusion(fnv, t.root, t.len, i, bs[i], path): return false
        if verifyInclusion(fnv, t.root, t.len, i, bs[i] & "x", path): return false        # wrong block
        if verifyInclusion(fnv, t.root, t.len, j, bs[i], path): return false              # wrong index
        if verifyInclusion(fnv, t.root, t.len, -1, bs[i], path): return false             # out of range
        if verifyInclusion(fnv, t.root, t.len, t.len, bs[i], path): return false
        let other = merkleTree(fnv, bs & @["one more"])
        if verifyInclusion(fnv, other.root, t.len, i, bs[i], path): return false          # wrong root
        if path.len > 0:
          if verifyInclusion(fnv, t.root, t.len, i, bs[i], path[0 ..< path.len - 1]): return false   # short
          var flipped = path
          flipped[0] = asDigest(path[0].toBytes & "!")
          if verifyInclusion(fnv, t.root, t.len, i, bs[i], flipped): return false
        verifyInclusion(fnv, t.root, t.len, i, bs[i], path & @[path[0]]) == false)       # long
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-MERKLE-06
  test "DS-MERKLE-06 Given blocks, when any one leaf changes or one is added or dropped, then the root changes":
    let outcome = check(pair(seqOf(stringOf("abc", 0, 6), 1, 30), intIn(0, 1000)),
      proc(a: (seq[string], int)): bool {.raises: [CatchableError].} =
        let bs = distinctBlocks(a[0])
        let t = merkleTree(fnv, bs)
        let i = a[1] mod bs.len
        var changed = bs
        changed[i] = bs[i] & "!"
        if merkleTree(fnv, changed).root == t.root: return false
        if merkleTree(fnv, bs & @["x"]).root == t.root: return false
        if merkleTree(fnv, bs[0 ..< bs.len - 1]).root == t.root: return false
        merkleTree(fnv, bs).root == t.root)       # and the same blocks give the same root
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-MERKLE-07
  test "DS-MERKLE-07 Given a tree, when a leaf is updated or a block appended, then the result equals a tree built from scratch and the old tree is unchanged":
    let outcome = check(pair(seqOf(stringOf("abc", 0, 6), 1, 40), pair(intIn(0, 1000), stringOf("xyz", 0, 5))),
      proc(a: (seq[string], (int, string))): bool {.raises: [CatchableError].} =
        let bs = a[0]
        let t = merkleTree(fnv, bs)
        let i = a[1][0] mod bs.len
        let nb = a[1][1]
        var bs2 = bs
        bs2[i] = nb
        let u = t.update(i, nb)
        if u.isNone or u.get != merkleTree(fnv, bs2): return false
        let grown = t.append(nb)
        if grown != merkleTree(fnv, bs & @[nb]): return false
        t == merkleTree(fnv, bs) and t.len == bs.len)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-MERKLE-08
  test "DS-MERKLE-08 Given n leaves, when one is updated or one appended, then only the nodes on one path are rebuilt and the rest is shared":
    let big = distinctBlocks(newSeq[string](1024))
    let t = merkleTree(fnv, big)
    check t.nodeCount == 2047
    let u = t.update(500, "changed").get
    check rebuiltNodes(t, u) == 11            # 10 inner nodes and the leaf: log2(1024) + 1 of 2047
    check rebuiltNodes(t, t.append("tail")) == 2      # 1024 is a power of two: a new root over the whole old tree and the new leaf
    check rebuiltNodes(t, t) == 0
    let outcome = check(pair(intIn(1, 300), intIn(0, 1000)),
      proc(a: (int, int)): bool {.raises: [CatchableError].} =
        let bs = distinctBlocks(newSeq[string](a[0]))
        let tr = merkleTree(fnv, bs)
        let i = a[1] mod a[0]
        let r = rebuiltNodes(tr, tr.update(i, "new").get)
        let app = rebuiltNodes(tr, tr.append("new"))
        tr.nodeCount == 2 * a[0] - 1 and r >= 1 and r <= ceilLog2(a[0]) + 1 and app <= ceilLog2(a[0]) + 2)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-MERKLE-09
  test "DS-MERKLE-09 Given no blocks or one block, when building, proving and updating, then the results are defined":
    let empty = merkleTree(fnv, newSeq[string]())
    check empty.len == 0
    check empty.root == emptyRoot(fnv)
    check empty.prove(0).isNone
    check empty.update(0, "x").isNone
    check empty.nodeCount == 0
    check empty.append("a") == merkleTree(fnv, ["a"])
    let one = merkleTree(fnv, ["only"])
    check one.len == 1
    check one.root == hashLeaf(fnv, "only")
    check one.prove(0) == some(newSeq[Digest]())
    check verifyInclusion(fnv, one.root, 1, 0, "only", newSeq[Digest]())
    check one.update(1, "x").isNone
    check one.update(-1, "x").isNone
    check one.update(0, "other").get.root == hashLeaf(fnv, "other")
    check one.root != empty.root
    check one.leafDigest(0) == some(hashLeaf(fnv, "only"))
    check one.leafDigest(1).isNone

  # SPEC: DS-MERKLE-10
  test "DS-MERKLE-10 Given an inner node's two digests, when they are offered as one leaf block, then the root differs from the real tree's":
    let two = merkleTree(fnv, ["left", "right"])
    let l = hashLeaf(fnv, "left")
    let r = hashLeaf(fnv, "right")
    # without a prefix byte this one-leaf tree would have the same root as `two` (second preimage)
    let forged = merkleTree(fnv, [l.toBytes & r.toBytes])
    check forged.root != two.root
    check two.root == hashInner(fnv, l, r)
    check hashLeaf(fnv, "x") != hashInner(fnv, l, r)
    # a proof for the forged leaf does not verify against the real root
    check not verifyInclusion(fnv, two.root, 1, 0, l.toBytes & r.toBytes, newSeq[Digest]())

  # SPEC: DS-MERKLE-11
  test "DS-MERKLE-11 Given a hash with collisions, when a colliding block is substituted, then get and the root accept it":
    let weak = lengthOnly()
    let stored = newCasStore(weak).put("abc")
    let swapped = loadUnverified(weak, [(stored.digest, "xyz")])
    check swapped.get(stored.digest) == ok("xyz", CasError)      # the guarantee is exactly as strong as the hash
    check merkleTree(weak, ["abc", "q"]).root == merkleTree(weak, ["xyz", "q"]).root
    check merkleTree(fnv, ["abc", "q"]).root != merkleTree(fnv, ["xyz", "q"]).root

  # SPEC: DS-MERKLE-12
  test "DS-MERKLE-12 Given blocks with a repeated last block, when building, then the root differs from the shorter list":
    # Bitcoin's tree duplicates an odd last node, so [a, b, c] and [a, b, c, c] share a root (CVE-2012-2459)
    let outcome = check(seqOf(stringOf("abc", 0, 5), 1, 40),
      proc(raw: seq[string]): bool {.raises: [CatchableError].} =
        let bs = distinctBlocks(raw)
        merkleTree(fnv, bs).root != merkleTree(fnv, bs & @[bs[^1]]).root)
    checkpoint describe(outcome)
    check outcome.passed
    check merkleTree(fnv, ["a", "b", "c"]).root != merkleTree(fnv, ["a", "b", "c", "c"]).root

  # SPEC: DS-MERKLE-13
  test "DS-MERKLE-13 Given no hash procedure or an empty name, when building a hasher, then an error says why":
    let noProc = newHasher("fnv", nil)
    check noProc.isErr
    check noProc.error == heNoProc
    let noName = newHasher("", proc(data: string): string {.noSideEffect, raises: [].} = data)
    check noName.error == heNoName
    check newHasher("identity", proc(data: string): string {.noSideEffect, raises: [].} = data).isOk
    check fnv.name == "insecure-fnv1a64"
    check addressOf(fnv, "").toBytes.len == 8
    check addressOf(fnv, "").toHex == "cbf29ce484222325"      # FNV-1a 64 of the empty input is its offset basis
    check addressOf(fnv, "a").toHex == "af63dc4c8601ec8c"      # published FNV-1a 64 test vector
