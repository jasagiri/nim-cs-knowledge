## Aho-Corasick: find every occurrence of every pattern of a fixed set in one pass over the text.
##
## The patterns go into a trie. A failure link sends each trie node to the node of the longest proper
## suffix of its string that is also in the trie, and the links are folded into a complete
## transition table, so reading the text never backs up: the work is linear in `text.len` plus the
## number of matches reported. Use it for many patterns over one text (word filters, signature
## scans); `kmp` is the choice for a single pattern and `rabin_karp` for many patterns of one length.
##
## The automaton is an immutable value built once by `buildAho`; searching leaves it unchanged, so
## the same automaton can be shared and reused. A match is a start offset plus the index of the
## pattern in the list given to `buildAho`; duplicate patterns are reported separately, each under
## its own index. Patterns must not be empty (an empty pattern occurs everywhere and carries no
## information); bytes are compared as they are, with no case folding.

import std/algorithm
import nimcs/fp/result

const AlphabetSize = 256

type
  AhoError* = enum
    aeEmptyPattern   ## one of the patterns is the empty string

  AhoCorasick* = object
    patternLens: seq[int]
    next: seq[int]            ## node * AlphabetSize + byte -> node (complete transition table)
    outputs: seq[seq[int]]    ## per node: pattern indices that end here, own and via failure links

  Match* = object
    start*: int      ## 0-based offset in the text where the occurrence begins
    pattern*: int    ## index of the pattern in the list given to `buildAho`

func `==`*(a, b: Match): bool {.raises: [].} =
  a.start == b.start and a.pattern == b.pattern

func `<`*(a, b: Match): bool {.raises: [].} =
  (a.start, a.pattern) < (b.start, b.pattern)

func buildAho*(patterns: openArray[string]): Result[AhoCorasick, AhoError] {.raises: [].} =
  ## The automaton for `patterns`. Fails with `aeEmptyPattern` when any pattern is empty
  ## (STR-AHOCORASICK-05).
  var trie = newSeq[int](AlphabetSize)       # -1 = no child yet; node 0 is the root
  for i in 0 ..< AlphabetSize:
    trie[i] = -1
  var outputs = @[newSeq[int]()]
  var lens = newSeq[int](patterns.len)
  for index, p in patterns:
    if p.len == 0:
      return err(AhoCorasick, aeEmptyPattern)
    lens[index] = p.len
    var node = 0
    for ch in p:
      let slot = node * AlphabetSize + ord(ch)
      if trie[slot] < 0:
        trie[slot] = outputs.len
        outputs.add newSeq[int]()
        for i in 0 ..< AlphabetSize:
          trie.add -1
      node = trie[slot]
    outputs[node].add index
  # Breadth-first: a node's failure node is shallower, so its table row and outputs are final.
  let nodeCount = outputs.len
  var fail = newSeq[int](nodeCount)
  var nextTable = trie
  var queue: seq[int]
  for c in 0 ..< AlphabetSize:
    let child = trie[c]
    if child < 0:
      nextTable[c] = 0
    else:
      queue.add child
  var head = 0
  while head < queue.len:
    let node = queue[head]
    inc head
    outputs[node] = outputs[node] & outputs[fail[node]]
    for c in 0 ..< AlphabetSize:
      let child = trie[node * AlphabetSize + c]
      if child < 0:
        nextTable[node * AlphabetSize + c] = nextTable[fail[node] * AlphabetSize + c]
      else:
        fail[child] = nextTable[fail[node] * AlphabetSize + c]
        queue.add child
  ok(AhoCorasick(patternLens: lens, next: nextTable, outputs: outputs), AhoError)

func patternCount*(a: AhoCorasick): int {.raises: [].} = a.patternLens.len

func findAll*(a: AhoCorasick; text: string): seq[Match] {.raises: [].} =
  ## Every occurrence of every pattern in `text`, overlapping ones included, ascending by
  ## (start, pattern index) (STR-AHOCORASICK-01, STR-AHOCORASICK-02).
  var node = 0
  for i, ch in text:
    node = a.next[node * AlphabetSize + ord(ch)]
    for index in a.outputs[node]:
      result.add Match(start: i + 1 - a.patternLens[index], pattern: index)
  result.sort

func countAll*(a: AhoCorasick; text: string): seq[int] {.raises: [].} =
  ## How many times each pattern occurs in `text`; entry `i` is for pattern `i`
  ## (STR-AHOCORASICK-04).
  result = newSeq[int](a.patternLens.len)
  var node = 0
  for ch in text:
    node = a.next[node * AlphabetSize + ord(ch)]
    for index in a.outputs[node]:
      inc result[index]
