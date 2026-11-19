# Zipper

## Intent
A zipper is a cursor into an immutable structure. It keeps the focused element and, in reverse, everything needed to put the structure back together. Moving the focus and replacing the focused element take constant time and share everything else.

## Use when / avoid when
- Use it for editors (text cursor), backtracking parsers, tree rewriting and "change this one place" updates.
- Use it when you navigate in small steps and edit near the focus.
- Avoid it when you transform every node: plain recursion is simpler.
- Avoid it for random access: use `pvector`.

## Nim shape
The module offers two zippers. `ListZipper[T]` holds `before` (nearest first), `focus` and `after` as `ConsList`s. `TreeZipper[T]` holds the focused `Tree[T]` and a trail of crumbs; a `Crumb` records the direction taken (an enum, matched exhaustively), the parent's value and the sibling subtree. Moves return `Option` (none past an end, at a leaf, or at the root). `modify` and `replace` edit the focus; `rebuild` goes up to the root.

```nim
import std/options
import nimcs/ds/zipper

let list = zipList([1, 2, 3]).get
let moved = list.moveRight.get.modify(proc(x: int): int = x * 10)
doAssert moved.toSeq == @[1, 20, 3]
doAssert list.toSeq == @[1, 2, 3]

let t = branch(branch(leaf[int](), 1, leaf[int]()), 2, branch(leaf[int](), 3, leaf[int]()))
let z = zipTree(t).downRight.get
let edited = z.modify(proc(x: int): int = x + 100).rebuild
doAssert edited.toSeq == @[1, 2, 103]
doAssert t.toSeq == @[1, 2, 3]
```

The main module is `src/nimcs/ds/zipper.nim`.

## Laws and invariants
- Moving right and then left returns to the same place (DS-ZIPPER-01).
- Setting the focus changes only the focused element and leaves the original unchanged (DS-ZIPPER-02).
- Moves past the ends are none, and an empty list has no zipper (DS-ZIPPER-03).
- Going down and back up rebuilds a tree equal to the original (DS-ZIPPER-04).
- Modifying at a path and rebuilding changes exactly that value, and the original tree is unchanged (DS-ZIPPER-05).
- Down at a leaf and up at the root are none, and modifying a leaf does nothing (DS-ZIPPER-06).
- Replacing the focused subtree puts it in that place after rebuilding (DS-ZIPPER-07).

## Complexity
| Operation | Time | Space |
|---|---|---|
| `moveLeft`, `moveRight`, `downLeft`, `downRight`, `up` | O(1) | O(1) new |
| `modify`, `replace`, `setFocus` | O(1) | O(1) new |
| `rebuild`, `toSeq` | O(depth) / O(n) | O(depth) / O(n) |

## Pitfalls
Updating a tree node by recursion from the root copies the path on every edit and loses the position.

```nim bad
type Tree = ref object
  value: int
  left, right: Tree

func setAt(t: Tree; path: seq[bool]; v: int): Tree =   # walks from the root on every call
  if t.isNil: return nil
  if path.len == 0: return Tree(value: v, left: t.left, right: t.right)
  if path[0]: Tree(value: t.value, left: t.left, right: setAt(t.right, path[1 .. ^1], v))
  else: Tree(value: t.value, left: setAt(t.left, path[1 .. ^1], v), right: t.right)
```

Keep a zipper at the place you are editing.

```nim
import std/options
import nimcs/ds/zipper

let t = branch(leaf[int](), 5, leaf[int]())
let z = zipTree(t).modify(proc(x: int): int = x + 1)
doAssert z.rebuild.toSeq == @[6]
```

## Related
`cons_list.nim`, `rb_tree.nim`, `trie.nim`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `14e1135a7e563bfa` CS240h: Functional Systems in Haskell
- `dfcd9e1737d42519` Exploring Generic Haskell
- `b8cf0456394ed527` Learn Programming with OCaml: Algorithms and Data Structures
- `93b1903990c81385` Learn You an Elm
- `90944eadae97da9a` Learning Scalaz
