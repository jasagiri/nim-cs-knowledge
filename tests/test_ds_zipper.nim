import std/[unittest, options]
import propcheck
import nimcs/ds/zipper

proc build(depth: int; next: var int): Tree[int] =
  if depth == 0: leaf[int]()
  else:
    let l = build(depth - 1, next)
    inc next
    let v = next
    branch(l, v, build(depth - 1, next))

proc sample(): Tree[int] =
  var next = 0
  build(3, next)

suite "zipper":
  # SPEC: DS-ZIPPER-01
  test "DS-ZIPPER-01 Given a list zipper, when moving right then left, then the zipper is back at the same place":
    let outcome = check(pair(seqOf(intIn(-9, 9), 1, 20), intIn(0, 19)),
      proc(a: (seq[int], int)): bool {.raises: [CatchableError].} =
        var z = zipList(a[0]).get
        for _ in 0 ..< a[1]:
          let n = z.moveRight
          if n.isNone: break
          z = n.get
        let there = z
        let r = there.moveRight
        if r.isSome:
          let back = r.get.moveLeft
          if back.isNone or back.get.toSeq != there.toSeq or back.get.position != there.position or
              back.get.focus != there.focus: return false
        true)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-ZIPPER-02
  test "DS-ZIPPER-02 Given a list zipper, when setting the focus, then only the focused element changes and the original is unchanged":
    let outcome = check(pair(seqOf(intIn(-9, 9), 1, 20), intIn(0, 19)),
      proc(a: (seq[int], int)): bool {.raises: [CatchableError].} =
        var z = zipList(a[0]).get
        var at = 0
        for _ in 0 ..< a[1]:
          let n = z.moveRight
          if n.isNone: break
          z = n.get
          inc at
        let edited = z.modify(proc(x: int): int = x + 100)
        var expected = a[0]
        expected[at] += 100
        edited.toSeq == expected and z.toSeq == a[0] and edited.position == at)
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: DS-ZIPPER-03
  test "DS-ZIPPER-03 Given the ends of a list, when moving beyond them, then the move is none; an empty list has no zipper":
    let z = zipList([1, 2]).get
    check z.moveLeft.isNone
    check z.moveRight.get.moveRight.isNone
    check zipList(newSeq[int]()).isNone

  # SPEC: DS-ZIPPER-04
  test "DS-ZIPPER-04 Given a tree zipper, when going down and back up, then the tree is rebuilt equal to the original":
    let t = sample()
    let z = zipTree(t)
    let l = z.downLeft.get
    check l.up.get.focusTree == t
    let lr = l.downRight.get
    check lr.up.get.up.get.focusTree == t
    check lr.depth == 2
    check lr.rebuild == t

  # SPEC: DS-ZIPPER-05
  test "DS-ZIPPER-05 Given a path, when modifying at its end and rebuilding, then exactly the value at that place changes and the original tree is unchanged":
    let t = sample()
    check t.toSeq == @[1, 2, 3, 4, 5, 6, 7]
    let z = zipTree(t).downLeft.get.downRight.get   # the node holding 3
    check z.focusTree.value == some(3)
    let edited = z.modify(proc(x: int): int = x * 10).rebuild
    check edited.toSeq == @[1, 2, 30, 4, 5, 6, 7]
    check t.toSeq == @[1, 2, 3, 4, 5, 6, 7]

  # SPEC: DS-ZIPPER-06
  test "DS-ZIPPER-06 Given a leaf or the root, when moving down past a leaf or up past the root, then the move is none":
    let z = zipTree(leaf[int]())
    check z.downLeft.isNone
    check z.downRight.isNone
    check z.up.isNone
    check z.modify(proc(x: int): int = x + 1).rebuild == leaf[int]()

  # SPEC: DS-ZIPPER-07
  test "DS-ZIPPER-07 Given a focused subtree, when replacing it, then the rebuilt tree contains the replacement in that place":
    let t = sample()
    let z = zipTree(t).downRight.get          # the right subtree rooted at 6
    let swapped = z.replace(branch(leaf[int](), 99, leaf[int]())).rebuild
    check swapped.toSeq == @[1, 2, 3, 4, 99]   # 5, 6, 7 are replaced by 99
    check t.toSeq == @[1, 2, 3, 4, 5, 6, 7]
