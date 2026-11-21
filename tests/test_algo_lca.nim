import std/[options, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/lca

proc shapes(): Gen[seq[int]] {.raises: [ValueError].} =
  ## Raw choices: vertex i (i >= 1) takes the parent `choice mod i`, so vertex 0 is the root and
  ## every parent has a smaller index; the tree is valid by construction.
  seqOf(intIn(0, 99), 0, 20)

func parentsOf(choices: seq[int]): seq[int] {.raises: [].} =
  result = @[-1]
  for i, c in choices:
    result.add c mod (i + 1)

func tree(parent: seq[int]): LcaTree {.raises: [].} =
  ## Only valid parent arrays are passed, so building cannot fail.
  buildLca(parent).value

func naiveDepth(parent: seq[int]; v: int): int {.raises: [].} =
  var current = v
  while parent[current] >= 0:
    current = parent[current]
    inc result

func naiveLca(parent: seq[int]; u, v: int): int {.raises: [].} =
  ## Oracle: the ancestors of u, then climb from v until one of them is met.
  var ancestors: seq[int]
  var current = u
  ancestors.add current
  while parent[current] >= 0:
    current = parent[current]
    ancestors.add current
  current = v
  while current notin ancestors:
    current = parent[current]
  current

# SPEC: LCA-QUERY-01
test "LCA-QUERY-01 Given a hand-drawn tree, when asking for ancestors, then the known answers come back":
  #        0
  #       / \
  #      1   2
  #     / \   \
  #    3   4   5
  #            |
  #            6
  let t = tree(@[-1, 0, 0, 1, 1, 2, 5])
  check t.lca(3, 4) == some(1)
  check t.lca(3, 6) == some(0)
  check t.lca(6, 5) == some(5)
  check t.lca(4, 4) == some(4)
  check t.lca(2, 1) == some(0)

# SPEC: LCA-QUERY-01
test "LCA-QUERY-01 Given any tree, when asking for the LCA of any pair, then it equals the walk-up oracle":
  let outcome = check(shapes(), proc(choices: seq[int]): bool {.raises: [CatchableError].} =
    let parent = parentsOf(choices)
    let t = tree(parent)
    var ok = true
    for u in 0 ..< parent.len:
      for v in 0 ..< parent.len:
        ok = ok and t.lca(u, v) == some(naiveLca(parent, u, v))
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: LCA-QUERY-02
test "LCA-QUERY-02 Given any tree, when asking for the LCA, then it is symmetric, the root with the root, and a parent with its child":
  let outcome = check(shapes(), proc(choices: seq[int]): bool {.raises: [CatchableError].} =
    let parent = parentsOf(choices)
    let t = tree(parent)
    var ok = true
    for u in 0 ..< parent.len:
      ok = ok and t.lca(u, u) == some(u) and t.lca(0, u) == some(0)
      for v in 0 ..< parent.len:
        ok = ok and t.lca(u, v) == t.lca(v, u)
        if t.kthAncestor(v, 1) == some(u):
          ok = ok and t.lca(u, v) == some(u)     # a parent is the LCA of itself and its child
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: LCA-DEPTH-01
test "LCA-DEPTH-01 Given any tree, when asking for depths, then they equal the walk-up count and the root has depth 0":
  let outcome = check(shapes(), proc(choices: seq[int]): bool {.raises: [CatchableError].} =
    let parent = parentsOf(choices)
    let t = tree(parent)
    var ok = t.depth(0) == some(0) and t.size == parent.len
    for v in 0 ..< parent.len:
      ok = ok and t.depth(v) == some(naiveDepth(parent, v))
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: LCA-ANCESTOR-01
test "LCA-ANCESTOR-01 Given any tree, when lifting k steps, then it equals k single steps and none past the root":
  let outcome = check(shapes(), proc(choices: seq[int]): bool {.raises: [CatchableError].} =
    let parent = parentsOf(choices)
    let t = tree(parent)
    var ok = true
    for v in 0 ..< parent.len:
      var current = v
      for k in 0 .. naiveDepth(parent, v):
        ok = ok and t.kthAncestor(v, k) == some(current)
        current = parent[current]
      ok = ok and t.kthAncestor(v, naiveDepth(parent, v) + 1).isNone
    ok and t.kthAncestor(0, -1).isNone)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: LCA-DISTANCE-01
test "LCA-DISTANCE-01 Given any tree, when measuring distance, then it is a metric matching the walk through the oracle LCA":
  let outcome = check(shapes(), proc(choices: seq[int]): bool {.raises: [CatchableError].} =
    let parent = parentsOf(choices)
    let t = tree(parent)
    var ok = true
    for u in 0 ..< parent.len:
      ok = ok and t.distance(u, u) == some(0)
      for v in 0 ..< parent.len:
        let m = naiveLca(parent, u, v)
        ok = ok and t.distance(u, v) == some(naiveDepth(parent, u) + naiveDepth(parent, v) - 2 * naiveDepth(parent, m))
        ok = ok and t.distance(u, v) == t.distance(v, u)
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: LCA-BUILD-01
test "LCA-BUILD-01 Given bad parent arrays, when building, then each defect has its own error":
  check buildLca(newSeq[int]()).error == leEmpty
  check buildLca(@[-1, 5]).error == leParentOutOfRange
  check buildLca(@[-1, -2]).error == leParentOutOfRange
  check buildLca(@[1, 0]).error == leRootCount          # no root at all
  check buildLca(@[-1, -1]).error == leRootCount        # two roots
  check buildLca(@[-1, 2, 1]).error == leNotConnected   # 1 and 2 point at each other
  check buildLca(@[1, -1]).isOk                         # the root need not be vertex 0
  check buildLca(@[-1]).isOk
  check buildLca(@[0]).error == leRootCount             # a vertex that is its own parent is no root

# SPEC: LCA-BUILD-02
test "LCA-BUILD-02 Given a vertex outside the tree, when querying, then the answer is none":
  let t = tree(@[-1, 0, 0])
  check t.lca(0, 3).isNone
  check t.lca(-1, 0).isNone
  check t.depth(7).isNone
  check t.distance(0, 9).isNone
  check t.kthAncestor(5, 0).isNone
  check 2 in t
  check 3 notin t

# SPEC: LCA-BUILD-03
test "LCA-BUILD-03 Given a tree whose root is not vertex 0 and parents have larger indices, when querying, then the answers still hold":
  # root 4; 3 hangs off 4; 2 off 3; 1 off 3; 0 off 2
  let t = tree(@[2, 3, 3, 4, -1])
  check t.lca(0, 1) == some(3)
  check t.depth(0) == some(3)
  check t.distance(0, 4) == some(3)
