## Persistent string trie: a set of words stored as a tree of characters.
##
## Each node has a flag "a word ends here" and children sorted by character. `insert` copies the
## nodes along the word (one per character) and shares every other branch. `contains` costs
## O(length of the word); `keysWithPrefix` walks to the prefix and lists the words below it in
## sorted (byte-wise) order. Recursion depth equals the word length (a release build handles words of
## tens of thousands of characters, a debug build about 2,000). Use it for autocompletion and prefix search; use `hamt` or `rb_tree`
## when you only need whole-key lookup.

type
  Node = ref object
    terminal: bool
    kids: seq[(char, Node)]   ## sorted by char, one entry per char
  Trie* = object
    root: Node
    count: int

func emptyTrie*(): Trie {.raises: [].} =
  Trie()

func len*(t: Trie): int {.raises: [].} =
  ## Number of distinct words.
  t.count

func isEmpty*(t: Trie): bool {.raises: [].} =
  t.count == 0

func childIndex(n: Node; c: char): int =
  ## Index of `c` in `n.kids`, or -1.
  for i, kid in n.kids:
    if kid[0] == c: return i
    if kid[0] > c: return -1
  -1

func walk(root: Node; s: string): Node =
  ## The node reached by `s`, or nil.
  var n = root
  for c in s:
    if n.isNil: return nil
    let i = childIndex(n, c)
    if i < 0: return nil
    n = n.kids[i][1]
  n

func contains*(t: Trie; word: string): bool {.raises: [].} =
  let n = walk(t.root, word)
  not n.isNil and n.terminal

func hasPrefix*(t: Trie; prefix: string): bool {.raises: [].} =
  ## True when at least one stored word starts with `prefix` (the word itself counts).
  let n = walk(t.root, prefix)
  not n.isNil and (n.terminal or n.kids.len > 0)

func insertAt(n: Node; word: string; i: int): Node =
  let base = if n.isNil: Node() else: n
  if i == word.len: return Node(terminal: true, kids: base.kids)
  let c = word[i]
  var kids = base.kids
  let at = childIndex(base, c)
  if at >= 0:
    kids[at] = (c, insertAt(base.kids[at][1], word, i + 1))
  else:
    var pos = kids.len
    for j, kid in kids:
      if kid[0] > c:
        pos = j
        break
    kids.insert((c, insertAt(nil, word, i + 1)), pos)
  Node(terminal: base.terminal, kids: kids)

func insert*(t: Trie; word: string): Trie {.raises: [].} =
  ## Adds `word`; adding a word that is already present gives an equal trie.
  if t.contains(word): t
  else: Trie(root: insertAt(t.root, word, 0), count: t.count + 1)

func collect(n: Node; prefix: string; into: var seq[string]) =
  if n.terminal: into.add prefix
  for kid in n.kids:
    collect(kid[1], prefix & kid[0], into)

func keysWithPrefix*(t: Trie; prefix: string): seq[string] {.raises: [].} =
  ## Every stored word that starts with `prefix`, in sorted order. The empty prefix lists all words.
  let n = walk(t.root, prefix)
  if not n.isNil:
    collect(n, prefix, result)

func toSeq*(t: Trie): seq[string] {.raises: [].} =
  t.keysWithPrefix("")

func fromSeq*(words: openArray[string]): Trie {.raises: [].} =
  var t = emptyTrie()
  for w in words:
    t = t.insert(w)
  t
