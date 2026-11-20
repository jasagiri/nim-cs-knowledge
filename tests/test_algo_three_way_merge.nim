import std/[unittest, options, tables, algorithm]
import propcheck
import nimcs/algo/lcs
import nimcs/algo/three_way_merge

func chars(s: string): seq[char] {.raises: [].} =
  result = @[]
  for c in s: result.add c

func lines(s: varargs[string]): seq[string] {.raises: [].} =
  result = @[]
  for x in s: result.add x

const noLines: seq[string] = @[]

func triple(): Gen[(string, (string, string))] {.raises: [ValueError].} =
  pair(stringOf("abc", 0, 8), pair(stringOf("abc", 0, 8), stringOf("abc", 0, 8)))

func tableFrom(cells: seq[int]): Table[string, int] {.raises: [].} =
  ## Cell i is key "k<i>": 0 means absent, otherwise the value.
  result = initTable[string, int]()
  for i, v in cells:
    if v > 0: result["k" & $i] = v

func tables(): Gen[(seq[int], (seq[int], seq[int]))] {.raises: [ValueError].} =
  let cells = seqOf(intIn(0, 2), 5, 5)
  pair(cells, pair(cells, cells))

func variant(n: int; ops: seq[int]; tag: string): seq[string] {.raises: [].} =
  ## Edit the base "b0".."b<n-1>" with fresh, side-unique lines: 0 keep, 1 delete, 2 keep and
  ## insert after, 3 insert before and keep, 4 replace.
  result = @[]
  for i in 0 ..< n:
    let op = if i < ops.len: ops[i] else: 0
    case op
    of 1: continue
    of 2:
      result.add "b" & $i
      result.add tag & $i
    of 3:
      result.add tag & $i
      result.add "b" & $i
    of 4: result.add tag & $i
    else: result.add "b" & $i

func edits(): Gen[(int, (seq[int], seq[int]))] {.raises: [ValueError].} =
  let ops = seqOf(intIn(0, 4), 0, 8)
  pair(intIn(0, 8), pair(ops, ops))

func baseOf(n: int): seq[string] {.raises: [].} =
  variant(n, @[], "x")

suite "keyed three-way merge":
  # SPEC: STR-MERGE3-01
  test "STR-MERGE3-01 Given a key changed on one side or the same way on both, when merging, then that change is taken":
    let base = {"a": 1, "b": 2, "c": 3, "d": 4}.toTable
    let ours = {"a": 1, "b": 20, "d": 4, "e": 5}.toTable      # b modified, c deleted, e added
    let theirs = {"a": 1, "b": 2, "c": 3, "d": 40, "f": 6}.toTable # d modified, f added
    let m = mergeKeyed(base, ours, theirs)
    check m.isClean
    check m.merged == {"a": 1, "b": 20, "d": 40, "e": 5, "f": 6}.toTable
    # the same change on both sides (a modification, a deletion, an addition) is not a conflict
    let same = mergeKeyed(base, {"a": 9, "b": 2, "d": 4, "g": 7}.toTable, {"a": 9, "b": 2, "d": 4, "g": 7}.toTable)
    check same.isClean
    check same.merged == {"a": 9, "b": 2, "d": 4, "g": 7}.toTable

  # SPEC: STR-MERGE3-02
  test "STR-MERGE3-02 Given a key changed differently on both sides, when merging, then a conflict value lists the key with all three versions":
    let base = {"a": 1, "b": 2, "c": 3}.toTable
    let ours = {"a": 10, "c": 3, "d": 4}.toTable         # a modified, b deleted, d added
    let theirs = {"a": 11, "b": 20, "c": 3, "d": 5}.toTable # a modified, b modified, d added
    let m = mergeKeyed(base, ours, theirs)
    check not m.isClean
    check m.resolved == {"c": 3}.toTable
    check m.conflicts == @[
      KeyConflict[int](key: "a", base: some(1), ours: some(10), theirs: some(11)),
      KeyConflict[int](key: "b", base: some(2), ours: none(int), theirs: some(20)),
      KeyConflict[int](key: "d", base: none(int), ours: some(4), theirs: some(5))]
    check conflictKeys(m) == @["a", "b", "d"]

  # SPEC: STR-MERGE3-03
  test "STR-MERGE3-03 Given any three maps, when merging, then the conflicting keys are exactly those changed differently on both sides":
    let outcome = check(tables(), proc(p: (seq[int], (seq[int], seq[int]))): bool {.raises: [CatchableError].} =
      let b = tableFrom(p[0])
      let o = tableFrom(p[1][0])
      let t = tableFrom(p[1][1])
      var expected: seq[string] = @[]
      for i in 0 ..< 5:
        let k = "k" & $i
        let bv = if k in b: some(b[k]) else: none(int)
        let ov = if k in o: some(o[k]) else: none(int)
        let tv = if k in t: some(t[k]) else: none(int)
        if ov != bv and tv != bv and ov != tv: expected.add k
      conflictKeys(mergeKeyed(b, o, t)) == expected)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: STR-MERGE3-04
  test "STR-MERGE3-04 Given any maps, when one side or both sides equal the base or each other, then the merge is clean and equals the changed side":
    let outcome = check(tables(), proc(p: (seq[int], (seq[int], seq[int]))): bool {.raises: [CatchableError].} =
      let b = tableFrom(p[0])
      let x = tableFrom(p[1][0])
      let a = mergeKeyed(b, b, b)
      let l = mergeKeyed(b, x, b)
      let r = mergeKeyed(b, b, x)
      let s = mergeKeyed(b, x, x)
      a.isClean and a.merged == b and l.isClean and l.merged == x and
        r.isClean and r.merged == x and s.isClean and s.merged == x)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: STR-MERGE3-05
  test "STR-MERGE3-05 Given any three maps, when ours and theirs are swapped, then clean results are equal and every conflict swaps its sides":
    let outcome = check(tables(), proc(p: (seq[int], (seq[int], seq[int]))): bool {.raises: [CatchableError].} =
      let b = tableFrom(p[0])
      let o = tableFrom(p[1][0])
      let t = tableFrom(p[1][1])
      swapSides(mergeKeyed(b, o, t)) == mergeKeyed(b, t, o))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: STR-MERGE3-06
  test "STR-MERGE3-06 Given a clean keyed merge, when reading a key either side changed, then the result carries that change, deletions included":
    let outcome = check(tables(), proc(p: (seq[int], (seq[int], seq[int]))): bool {.raises: [CatchableError].} =
      let b = tableFrom(p[0])
      let o = tableFrom(p[1][0])
      let t = tableFrom(p[1][1])
      let m = mergeKeyed(b, o, t)
      if not m.isClean: return true
      for i in 0 ..< 5:
        let k = "k" & $i
        let changedOurs = (k in o) != (k in b) or (k in o and k in b and o[k] != b[k])
        let src = if changedOurs: o else: t
        if (k in m.merged) != (k in src): return false
        if k in src and m.merged[k] != src[k]: return false
      true)
    checkpoint describe(outcome)
    check outcome.passed

suite "sequence three-way merge (diff3)":
  # SPEC: STR-MERGE3-07
  test "STR-MERGE3-07 Given hand-worked line edits, when merging, then non-overlapping edits merge and overlapping ones become conflict hunks":
    # edits in different places: both are kept
    check merge3(lines("a", "b", "c", "d", "e"), lines("a", "X", "c", "d", "e"), lines("a", "b", "c", "d", "Y")) ==
      @[stable(lines("a")), clean(sOurs, lines("X")), stable(lines("c", "d")), clean(sTheirs, lines("Y"))]
    # the same line changed differently
    check merge3(lines("a", "b", "c"), lines("a", "X", "c"), lines("a", "Y", "c")) ==
      @[stable(lines("a")), conflict(lines("b"), lines("X"), lines("Y")), stable(lines("c"))]
    # the same change on both sides
    check merge3(lines("a", "b", "c"), lines("a", "X", "c"), lines("a", "X", "c")) ==
      @[stable(lines("a")), clean(sBoth, lines("X")), stable(lines("c"))]
    # the same deletion on both sides
    check merge3(lines("a", "b", "c"), lines("a", "c"), lines("a", "c")) ==
      @[stable(lines("a")), clean(sBoth, noLines), stable(lines("c"))]
    # delete against modify
    check merge3(lines("a", "b", "c"), lines("a", "c"), lines("a", "Y", "c")) ==
      @[stable(lines("a")), conflict(lines("b"), noLines, lines("Y")), stable(lines("c"))]
    # two different insertions into the same gap
    check merge3(lines("a", "b"), lines("a", "x", "b"), lines("a", "y", "b")) ==
      @[stable(lines("a")), conflict(noLines, lines("x"), lines("y")), stable(lines("b"))]
    # edits on neighbouring lines are one overlapping hunk, as in diff3
    check merge3(lines("a", "b", "c"), lines("a", "X", "c"), lines("a", "b", "Y")) ==
      @[stable(lines("a")), conflict(lines("b", "c"), lines("X", "c"), lines("b", "Y"))]
    # nothing at all
    check merge3(newSeq[string](), newSeq[string](), newSeq[string]()).len == 0

  # SPEC: STR-MERGE3-08
  test "STR-MERGE3-08 Given any sequences, when one side or both sides equal the base or each other, then the merge is clean and equals the changed side":
    let outcome = check(triple(), proc(p: (string, (string, string))): bool {.raises: [CatchableError].} =
      let b = chars(p[0])
      let x = chars(p[1][0])
      let same = merge3(b, b, b)
      let l = mergeLines(merge3(b, x, b))
      let r = mergeLines(merge3(b, b, x))
      let s = mergeLines(merge3(b, x, x))
      same == (if b.len == 0: newSeq[Chunk[char]]() else: @[stable(b)]) and
        l == some(x) and r == some(x) and s == some(x))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: STR-MERGE3-09
  test "STR-MERGE3-09 Given any sequences, when ours and theirs are swapped, then clean chunks are equal and every conflict swaps its sides":
    let outcome = check(triple(), proc(p: (string, (string, string))): bool {.raises: [CatchableError].} =
      let b = chars(p[0])
      let o = chars(p[1][0])
      let t = chars(p[1][1])
      swapSides(merge3(b, o, t)) == merge3(b, t, o))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: STR-MERGE3-10
  test "STR-MERGE3-10 Given edits with unique lines, when the merge is clean, then it holds every inserted line, every line both sides kept, and no deleted one, in each side's order":
    let outcome = check(edits(), proc(p: (int, (seq[int], seq[int]))): bool {.raises: [CatchableError].} =
      let b = baseOf(p[0])
      let o = variant(p[0], p[1][0], "o")
      let t = variant(p[0], p[1][1], "t")
      let merged = mergeLines(merge3(b, o, t))
      if merged.isNone: return true
      let m = merged.get
      var expected: seq[string] = @[]
      for l in o:
        if l notin b or l in t: expected.add l
      for l in t:
        if l notin b and l notin o: expected.add l
      var got = m
      got.sort()
      expected.sort()
      var ofOurs: seq[string] = @[]
      for l in o:
        if l in m: ofOurs.add l
      var ofTheirs: seq[string] = @[]
      for l in t:
        if l in m: ofTheirs.add l
      got == expected and isSubsequence(ofOurs, m) and isSubsequence(ofTheirs, m))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: STR-MERGE3-11
  test "STR-MERGE3-11 Given any sequences, when merging, then no two stable chunks touch and a conflict differs on every pair of its three sides":
    let outcome = check(triple(), proc(p: (string, (string, string))): bool {.raises: [CatchableError].} =
      let cs = merge3(chars(p[0]), chars(p[1][0]), chars(p[1][1]))
      for i, c in cs:
        case c.kind
        of ckStable:
          if c.stable.len == 0: return false
          if i > 0 and cs[i - 1].kind == ckStable: return false
        of ckClean: discard
        of ckConflict:
          if c.ours == c.theirs or c.ours == c.base or c.theirs == c.base: return false
      true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: STR-MERGE3-12
  test "STR-MERGE3-12 Given a merge, when rendering, then a clean one is its lines and a conflict is fenced by the usual markers":
    let clean = merge3(lines("a", "b"), lines("a", "b", "c"), lines("a", "b"))
    check render(clean) == "a\nb\nc\n"
    let hunk = merge3(lines("a", "b", "c"), lines("a", "X", "c"), lines("a", "Y", "c"))
    check render(hunk) == "a\n<<<<<<< ours\nX\n||||||| base\nb\n=======\nY\n>>>>>>> theirs\nc\n"
    check render(hunk, "mine", "ancestor", "yours") ==
      "a\n<<<<<<< mine\nX\n||||||| ancestor\nb\n=======\nY\n>>>>>>> yours\nc\n"
    check toLines("a\nb\n") == lines("a", "b")
    check toLines("a\nb") == lines("a", "b")
    check toLines("") == newSeq[string]()
    check mergeLines(hunk).isNone
    check conflictCount(hunk) == 1
    check conflictCount(clean) == 0
