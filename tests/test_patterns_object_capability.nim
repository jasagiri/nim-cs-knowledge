import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/patterns/object_capability

const
  Rights = [{rtRead, rtWrite}, {rtRead}, {rtWrite}, {}]
  Prefixes = ["", "a", "a/b", "c"]
  Subs = ["x", "x/y", "b", "..", "", "a", "q/", "/q", "./x", "b/c"]
  Paths = ["a/b/x", "a/x", "a/b/x/y", "c/x", "x", "a/../c/x", "/a/x", "ab/x", "a/b", "a", "", "a//x"]

func parentCap(rightsAt, prefixAt: int): FileCap {.raises: [].} =
  var c = rootCap(Rights[rightsAt])
  if Prefixes[prefixAt].len > 0:
    let n = c.narrow(Prefixes[prefixAt])
    doAssert n.isOk
    c = n.value
  c

# SPEC: PAT-OBJCAP-01
test "PAT-OBJCAP-01 Given a capability and any attenuation of it, when a path and right are tried, then the attenuated one never permits what its parent does not":
  let outcome = check(pair(pair(intIn(0, 3), intIn(0, 3)), pair(pair(intIn(0, 3), intIn(0, 9)), pair(intIn(0, 11), boolean()))),
      proc(x: ((int, int), ((int, int), (int, bool)))): bool {.raises: [CatchableError].} =
    let parent = parentCap(x[0][0], x[0][1])
    let keep = Rights[x[1][0][0]]
    let narrowed = parent.restrict(keep).narrow(Subs[x[1][0][1]])
    let right = if x[1][1][1]: rtRead else: rtWrite
    let path = Paths[x[1][1][0]]
    if narrowed.isErr: true          # a refused attenuation grants nothing at all
    else:
      let child = narrowed.value
      (not child.permits(right, path) or parent.permits(right, path)) and
        child.rights <= parent.rights)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-OBJCAP-02
test "PAT-OBJCAP-02 Given the capability type, when code outside its module tries to build or default one, then it does not compile":
  check not compiles(FileCap(held: {rtRead}, base: @[]))
  check not compiles(FileCap())
  check not compiles(block:
    var c: FileCap
    discard c)
  # No ambient authority: every operation takes the capability as an argument.
  check not compiles(read(emptyStore(), "a/x"))
  check not compiles(write(emptyStore(), "a/x", "data"))
  check compiles(read(emptyStore(), rootCap({rtRead}), "a/x"))

# SPEC: PAT-OBJCAP-03
test "PAT-OBJCAP-03 Given a path prefix capability, when paths are tried, then only whole segments below the prefix pass and dot segments, empty segments and absolute paths are refused":
  let c = parentCap(0, 1)                       # read and write under "a"
  check c.permits(rtRead, "a/x")
  check c.permits(rtRead, "a/b/c/d")
  check not c.permits(rtRead, "ab/x")           # a prefix of the text is not a prefix of the path
  check not c.permits(rtRead, "a")              # the directory itself is not a file under it
  check not c.permits(rtRead, "a/../c/x")
  check not c.permits(rtRead, "/a/x")
  check not c.permits(rtRead, "a//x")
  check not c.permits(rtRead, "")
  check c.prefix == "a"
  let deeper = c.narrow("b/c")
  check deeper.value.prefix == "a/b/c"
  check c.narrow("..").error == ceBadPath
  check c.narrow("").error == ceBadPath
  check c.narrow("x/").error == ceBadPath

# SPEC: PAT-OBJCAP-04
test "PAT-OBJCAP-04 Given a chain of attenuations, when narrowed in two steps or in one, then the result is the same capability":
  let outcome = check(pair(intIn(0, 3), pair(intIn(0, 3), intIn(0, 3))), proc(x: (int, (int, int))): bool {.raises: [CatchableError].} =
    let root = rootCap(Rights[x[0]])
    let names = ["a", "b", "c", "d"]
    let p = names[x[1][0]]
    let q = names[x[1][1]]
    let first = root.narrow(p)
    let twoSteps = if first.isOk: first.value.narrow(q) else: first
    twoSteps == root.narrow(p & "/" & q))
  checkpoint describe(outcome)
  check outcome.passed
  let one = rootCap({rtRead}).narrow("a/b")
  let two = rootCap({rtRead}).narrow("a").value.narrow("b")
  check one.value == two.value

# SPEC: PAT-OBJCAP-05
test "PAT-OBJCAP-05 Given a read-only capability, when it is used to write, then the write is denied and the store is unchanged; with a write capability the store changes and the old store does not":
  let rw = parentCap(0, 1)
  let ro = rw.readOnly
  let s0 = emptyStore()
  let s1 = s0.write(rw, "a/f", "hello")
  check s1.isOk
  check s0.read(rw, "a/f").error == ceNotFound            # the old store is unchanged
  check s1.value.read(rw, "a/f").value == "hello"
  check s1.value.read(ro, "a/f").value == "hello"         # read-only still reads
  check s1.value.write(ro, "a/f", "x").error == ceDenied
  check s1.value.write(rw, "b/f", "x").error == ceOutside
  check s1.value.read(rw, "a/../a/f").error == ceBadPath
  check ro.rights == {rtRead}

# SPEC: PAT-OBJCAP-06
test "PAT-OBJCAP-06 Given a capability passed to another routine, when that routine uses it, then it can do exactly what the passed value allows and a copy allows the same":
  func archive(store: Store; src: FileCap): int {.raises: [].} =
    ## A callee that was handed a capability and nothing else: counts the readable files.
    var n = 0
    for p in ["a/1", "a/2", "b/1"]:
      if store.read(src, p).isOk: inc n
    n
  var s = emptyStore()
  for p in ["a/1", "a/2", "b/1"]:
    s = s.write(rootCap({rtRead, rtWrite}), p, "data").value
  let cap = parentCap(1, 1)
  let copy = cap
  check archive(s, cap) == 2
  check archive(s, copy) == archive(s, cap)
  check archive(s, rootCap({rtRead})) == 3
  check archive(s, parentCap(1, 3)) == 0
  check archive(s, cap.restrict({})) == 0
