## Binomial heap: a persistent min-heap whose merge works like binary addition.
##
## A heap is a list of binomial trees in increasing rank, at most one tree per rank, exactly like
## the set bits of n. A tree of rank r has 2^r nodes; linking two trees of rank r gives one of
## rank r+1 (a carry). `insert`, `merge` and `deleteMin` are O(log n) worst case; `insert` is O(1)
## amortized only for ephemeral use (a run of inserts where each version is used once), because
## a persistent program can repeat the longest carry chain from one old version. Use it when you
## want the arithmetic analogy to guide the reasoning and a worst-case O(log n) bound for all
## three operations.

import std/options
import nimcs/ds/cons_list

type
  Tree[T] = ref object
    rank: int
    elem: T
    children: ConsList[Tree[T]]   ## ranks decreasing: rank-1 first, rank 0 last
  BinomialHeap*[T] = object
    trees: ConsList[Tree[T]]      ## ranks increasing, all different
    size: int

func emptyHeap*[T](): BinomialHeap[T] {.raises: [].} =
  BinomialHeap[T]()

func len*[T](h: BinomialHeap[T]): int {.raises: [].} =
  h.size

func isEmpty*[T](h: BinomialHeap[T]): bool {.raises: [].} =
  h.trees.isEmpty

func link[T](a, b: Tree[T]): Tree[T] =
  ## Same rank in, rank + 1 out; the smaller root stays on top.
  if b.elem < a.elem: Tree[T](rank: b.rank + 1, elem: b.elem, children: b.children.cons(a))
  else: Tree[T](rank: a.rank + 1, elem: a.elem, children: a.children.cons(b))

func rankOf[T](ts: ConsList[Tree[T]]): int =
  ts.head.get.rank

func insertTree[T](t: Tree[T]; ts: ConsList[Tree[T]]): ConsList[Tree[T]] =
  if ts.isEmpty or t.rank < rankOf(ts): ts.cons(t)
  else: insertTree(link(t, ts.head.get), ts.tail)

func mergeTrees[T](a, b: ConsList[Tree[T]]): ConsList[Tree[T]] =
  if a.isEmpty: b
  elif b.isEmpty: a
  else:
    let ta = a.head.get
    let tb = b.head.get
    if ta.rank < tb.rank: mergeTrees(a.tail, b).cons(ta)
    elif tb.rank < ta.rank: mergeTrees(a, b.tail).cons(tb)
    else: insertTree(link(ta, tb), mergeTrees(a.tail, b.tail))

func merge*[T](a, b: BinomialHeap[T]): BinomialHeap[T] {.raises: [].} =
  BinomialHeap[T](trees: mergeTrees(a.trees, b.trees), size: a.size + b.size)

func insert*[T](h: BinomialHeap[T]; x: T): BinomialHeap[T] {.raises: [].} =
  BinomialHeap[T](trees: insertTree(Tree[T](rank: 0, elem: x), h.trees), size: h.size + 1)

func minTree[T](ts: ConsList[Tree[T]]): Tree[T] =
  ## `ts` is not empty.
  var best = ts.head.get
  for t in items(ts):
    if t.elem < best.elem: best = t
  best

func findMin*[T](h: BinomialHeap[T]): Option[T] {.raises: [].} =
  if h.isEmpty: none(T) else: some(minTree(h.trees).elem)

func deleteMin*[T](h: BinomialHeap[T]): BinomialHeap[T] {.raises: [].} =
  if h.isEmpty: h
  else:
    let best = minTree(h.trees)
    var others = emptyList[Tree[T]]()
    var removed = false
    for t in items(h.trees):
      if not removed and t == best:   # reference identity: remove exactly this tree
        removed = true
      else:
        others = others.cons(t)
    BinomialHeap[T](trees: mergeTrees(others.reverse, best.children.reverse), size: h.size - 1)

func fromSeq*[T](items: openArray[T]): BinomialHeap[T] {.raises: [].} =
  var h = emptyHeap[T]()
  for x in items:
    h = h.insert(x)
  h

func toSortedSeq*[T](h: BinomialHeap[T]): seq[T] {.raises: [].} =
  var cur = h
  while not cur.isEmpty:
    result.add minTree(cur.trees).elem
    cur = cur.deleteMin

func rankProfile*[T](h: BinomialHeap[T]): seq[int] {.raises: [].} =
  ## The ranks present, increasing. They are the positions of the 1 bits of `len`.
  for t in items(h.trees):
    result.add t.rank

func invariantsHold*[T](h: BinomialHeap[T]): bool {.raises: [].} =
  ## Strictly increasing ranks, each tree heap-ordered with 2^rank nodes.
  func count(t: Tree[T]): int =
    result = 1
    for c in items(t.children):
      result += count(c)
  func ordered(t: Tree[T]): bool =
    result = true
    for c in items(t.children):
      if c.elem < t.elem or not ordered(c): return false
  var prev = -1
  for t in items(h.trees):
    if t.rank <= prev or count(t) != (1 shl t.rank) or not ordered(t): return false
    prev = t.rank
  true
