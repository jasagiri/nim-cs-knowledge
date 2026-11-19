import std/unittest
import propcheck
import nimcs/patterns/composite

func build(xs: seq[int]): Entry {.raises: [].} =
  ## Balanced tree over the sizes: empty list is an empty directory, one size is a file.
  if xs.len == 0:
    dir("empty", @[])
  elif xs.len == 1:
    file("f", xs[0])
  else:
    let mid = xs.len div 2
    dir("d", @[build(xs[0 ..< mid]), build(xs[mid .. ^1])])

func sum(xs: seq[int]): int {.raises: [].} =
  for x in xs: result += x

func sizes(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(0, 99), 0, 20)

# SPEC: GOF-COMPOSITE-01
test "GOF-COMPOSITE-01 Given any tree, when totalled, then the size is the sum of its leaves":
  let outcome = check(sizes(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    build(xs).totalSize == sum(xs))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-COMPOSITE-02
test "GOF-COMPOSITE-02 Given any tree, when counted and flattened, then leaves are counted and listed in order":
  let outcome = check(sizes(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let t = build(xs)
    t.fileCount == xs.len and t.leafSizes == xs)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-COMPOSITE-03
test "GOF-COMPOSITE-03 Given any tree, when an empty directory is added, then size and count do not change":
  let outcome = check(sizes(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let t = build(xs)
    let wrapped = dir("root", @[t, dir("nothing", @[])])
    wrapped.totalSize == t.totalSize and wrapped.fileCount == t.fileCount)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-COMPOSITE-03
test "GOF-COMPOSITE-03 Given children, when grouped in a directory, then size and count do not change":
  let outcome = check(pair(sizes(), sizes()), proc(p: (seq[int], seq[int])): bool {.raises: [CatchableError].} =
    let a = build(p[0])
    let b = build(p[1])
    let flat = dir("x", @[a, b])
    let nested = dir("x", @[dir("g", @[a, b])])
    flat.totalSize == nested.totalSize and flat.fileCount == nested.fileCount and
      flat.leafSizes == nested.leafSizes)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-COMPOSITE-04
test "GOF-COMPOSITE-04 Given a file and nested directories, when depth is taken, then it counts the levels":
  check file("a", 1).depth == 0
  check dir("d", @[]).depth == 1
  check dir("d", @[file("a", 1), dir("e", @[file("b", 2)])]).depth == 2

# SPEC: GOF-COMPOSITE-04
test "GOF-COMPOSITE-04 Given any children, when wrapped in a directory, then depth is one more than the deepest child":
  let outcome = check(pair(sizes(), sizes()), proc(p: (seq[int], seq[int])): bool {.raises: [CatchableError].} =
    let a = build(p[0])
    let b = build(p[1])
    dir("x", @[a, b]).depth == max(a.depth, b.depth) + 1)
  checkpoint describe(outcome)
  check outcome.passed
