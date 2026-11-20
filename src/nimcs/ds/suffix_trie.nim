## Naive suffix trie for small texts: substring counts, distinct substrings, longest repeat.
##
## This is not a suffix tree. A suffix tree compresses unary paths and is built in O(n) by
## Ukkonen's algorithm, which needs suffix links and shared mutable end indices; that does not fit
## the persistent, value-only style of this repository without losing the O(n) bound. This module
## instead inserts every suffix of the text into a plain trie (one node per character), which is
## simple, immutable and obviously correct, but takes O(n^2) nodes: `buildSuffixTrie` refuses texts
## longer than `maxTextLen`. Each node stores how many suffixes pass through it, which equals the
## number of (possibly overlapping) occurrences of the string spelled by the path. Use it to learn
## what a suffix tree answers and to test other implementations on short strings; for real texts
## use `suffix_array` in `nimcs/algo`.

import nimcs/fp/result

const maxTextLen* = 400
  ## Longest text accepted; the trie of a text of length n has up to n(n+1)/2 nodes.

type
  Node = ref object
    count: int                                        ## suffixes passing through this node
    kids: seq[tuple[c: char, child: Node]]            ## sorted by character
  SuffixTrie* = object
    root: Node
    textLen: int
  TrieError* = enum
    textTooLong   ## the text is longer than `maxTextLen`

func childOf(n: Node; c: char): Node =
  for k in n.kids:
    if k.c == c: return k.child
  nil

func withChild(kids: seq[tuple[c: char, child: Node]]; c: char; child: Node): seq[tuple[c: char, child: Node]] =
  ## A copy of `kids` where the entry for `c` is `child`, keeping the order by character.
  var placed = false
  for k in kids:
    if k.c == c:
      result.add (c: c, child: child)
      placed = true
    elif not placed and c < k.c:
      result.add (c: c, child: child)
      result.add k
      placed = true
    else:
      result.add k
  if not placed:
    result.add (c: c, child: child)

func insertSuffix(n: Node; text: string; i: int): Node =
  ## A copy of `n` with the suffix `text[i..]` added; the untouched subtrees are shared.
  if i >= text.len:
    return Node(count: n.count, kids: n.kids)
  let c = text[i]
  let old = childOf(n, c)
  let base = if old.isNil: Node() else: old
  let below = insertSuffix(base, text, i + 1)
  let counted = Node(count: base.count + 1, kids: below.kids)
  Node(count: n.count, kids: withChild(n.kids, c, counted))

func buildSuffixTrie*(text: string): Result[SuffixTrie, TrieError] {.raises: [].} =
  ## Builds the trie of all suffixes of `text` (bytes are the characters). Fails with
  ## `textTooLong` above `maxTextLen`.
  if text.len > maxTextLen:
    return err(SuffixTrie, textTooLong)
  var root = Node()
  for i in 0 ..< text.len:
    root = insertSuffix(root, text, i)
  ok(SuffixTrie(root: root, textLen: text.len), TrieError)

func textLen*(t: SuffixTrie): int {.raises: [].} =
  t.textLen

func walk(t: SuffixTrie; s: string): Node =
  var n = t.root
  for c in s:
    n = childOf(n, c)
    if n.isNil: return nil
  n

func count*(t: SuffixTrie; sub: string): int {.raises: [].} =
  ## How many times `sub` occurs in the text, overlapping occurrences included. The empty string
  ## occurs `textLen + 1` times (once at every position, end included), as in a naive scan.
  if sub.len == 0: return t.textLen + 1
  let n = walk(t, sub)
  if n.isNil: 0 else: n.count

func contains*(t: SuffixTrie; sub: string): bool {.raises: [].} =
  not walk(t, sub).isNil

func countNodes(n: Node): int =
  result = 1
  for k in n.kids:
    result += countNodes(k.child)

func distinctSubstrings*(t: SuffixTrie): int {.raises: [].} =
  ## The number of different non-empty substrings: every node except the root is one.
  countNodes(t.root) - 1

func deepestRepeat(n: Node; path: string): string =
  ## The longest string below `n` with count >= 2, smallest first among equal lengths because the
  ## children are visited in character order and only a strictly longer one replaces the best.
  result = path
  for k in n.kids:
    if k.child.count >= 2:
      let cand = deepestRepeat(k.child, path & k.c)
      if cand.len > result.len:
        result = cand

func longestRepeated*(t: SuffixTrie): string {.raises: [].} =
  ## The longest substring that occurs at least twice (occurrences may overlap); among equally
  ## long ones the lexicographically smallest. Empty when no character repeats.
  deepestRepeat(t.root, "")

func shortestAbsent*(t: SuffixTrie; alphabet: string): string {.raises: [].} =
  ## The shortest string over `alphabet` that is not a substring of the text; among equally short
  ## ones the smallest in the order of `alphabet`. `alphabet` must be non-empty and have distinct
  ## characters; an empty `alphabet` gives "".
  if alphabet.len == 0: return ""
  var level: seq[tuple[s: string, n: Node]] = @[(s: "", n: t.root)]
  while true:
    var nextLevel: seq[tuple[s: string, n: Node]]
    for (s, n) in level:
      for c in alphabet:
        let child = childOf(n, c)
        if child.isNil: return s & c
        nextLevel.add (s: s & c, n: child)
    level = nextLevel
