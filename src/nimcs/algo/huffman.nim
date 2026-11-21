## Huffman coding: a prefix-free binary code that gives frequent symbols short code words.
##
## Use it to see how a greedy choice (always merge the two lightest subtrees) builds an optimal
## symbol-by-symbol code. The code words are returned as strings of '0' and '1' so that a reader
## can print and compare them; a real encoder would pack bits. Ties are broken by weight, then
## by the smallest symbol inside a subtree, and the first subtree taken becomes the 0 side, so the
## same frequencies give the same code whatever order they arrive in. Nothing is changed in place.

import std/[algorithm, heapqueue, options]
import nimcs/fp/result

type
  HuffmanError* = enum
    heEmptyInput       ## no symbol to build a code from
    heBadFrequency     ## a frequency below one
    heDuplicateSymbol  ## the same symbol listed twice
    heWeightOverflow   ## the total weight does not fit in an `int`
    heUnknownSymbol    ## `encode` met a symbol that has no code word
    heBadBits          ## `decode` met a character other than '0' or '1', a path that leads nowhere, or an unfinished code word

  Node = object
    weight, minSym: int
    sym: char
    left, right: int   ## indices into `nodes`; -1 for a leaf

  HuffmanCode* = object
    nodes: seq[Node]
    root: int
    words: seq[(char, string)]   ## ascending by symbol

func frequencies*(text: string): seq[(char, int)] {.raises: [].} =
  ## How often each character occurs, ascending by character; absent characters are left out.
  var counts: array[256, int]
  for c in text:
    inc counts[ord(c)]
  for i in 0 .. 255:
    if counts[i] > 0:
      result.add (char(i), counts[i])

func lookup(words: seq[(char, string)]; c: char): Option[string] =
  var lo = 0
  var hi = words.len - 1
  while lo <= hi:
    let mid = (lo + hi) div 2
    if words[mid][0] == c:
      return some(words[mid][1])
    if words[mid][0] < c: lo = mid + 1 else: hi = mid - 1
  none(string)

func wordsOf(nodes: seq[Node]; root: int): seq[(char, string)] =
  ## Walks the tree; a lone leaf gets the word "0" so that every symbol costs at least one bit.
  if nodes[root].left < 0:
    return @[(nodes[root].sym, "0")]
  var found: seq[(char, string)]
  var stack = @[(root, "")]
  while stack.len > 0:
    let (n, prefix) = stack.pop
    if nodes[n].left < 0:
      found.add (nodes[n].sym, prefix)
    else:
      stack.add (nodes[n].right, prefix & "1")
      stack.add (nodes[n].left, prefix & "0")
  sorted(found, proc(a, b: (char, string)): int = cmp(a[0], b[0]))

func buildCode*(freqs: openArray[(char, int)]): Result[HuffmanCode, HuffmanError] {.raises: [].} =
  ## The Huffman code of the given (symbol, frequency) pairs, in any order (CODING-HUFFMAN-01).
  ## Fails on an empty list, a frequency below one, a repeated symbol or a total that overflows
  ## (CODING-HUFFMAN-05).
  if freqs.len == 0:
    return err(HuffmanCode, heEmptyInput)
  let ordered = sorted(@freqs, proc(a, b: (char, int)): int = cmp(a[0], b[0]))
  var total = 0
  for i, (c, f) in ordered:
    if f < 1:
      return err(HuffmanCode, heBadFrequency)
    if i > 0 and ordered[i - 1][0] == c:
      return err(HuffmanCode, heDuplicateSymbol)
    if f > high(int) - total:
      return err(HuffmanCode, heWeightOverflow)
    total += f
  var nodes: seq[Node]
  var queue = initHeapQueue[(int, int, int)]()   # (weight, smallest symbol inside, node index)
  for (c, f) in ordered:
    nodes.add Node(weight: f, minSym: ord(c), sym: c, left: -1, right: -1)
    queue.push (f, ord(c), nodes.high)
  while queue.len > 1:
    let a = queue.pop
    let b = queue.pop
    nodes.add Node(weight: a[0] + b[0], minSym: min(a[1], b[1]), sym: '\0', left: a[2], right: b[2])
    queue.push (a[0] + b[0], min(a[1], b[1]), nodes.high)
  let root = queue.pop[2]
  ok(HuffmanCode(nodes: nodes, root: root, words: wordsOf(nodes, root)), HuffmanError)

func codeWords*(code: HuffmanCode): seq[(char, string)] {.raises: [].} =
  ## Every symbol with its code word, ascending by symbol.
  code.words

func wordOf*(code: HuffmanCode; c: char): Option[string] {.raises: [].} =
  ## The code word of `c`; none when `c` was not in the frequency list.
  lookup(code.words, c)

func isPrefixFree*(code: HuffmanCode): bool {.raises: [].} =
  ## True when no code word begins another. Always true for a built code (CODING-HUFFMAN-02); the check
  ## exists so a test can state the law instead of trusting the construction.
  for i in 0 ..< code.words.len:
    for j in 0 ..< code.words.len:
      if i != j:
        let a = code.words[i][1]
        let b = code.words[j][1]
        if a.len <= b.len and b[0 ..< a.len] == a:
          return false
  true

func encode*(code: HuffmanCode; text: string): Result[string, HuffmanError] {.raises: [].} =
  ## The concatenated code words of the characters of `text` (CODING-HUFFMAN-03). Fails with
  ## `heUnknownSymbol` on a character the code does not know (CODING-HUFFMAN-06).
  var bits = ""
  for c in text:
    let w = lookup(code.words, c)
    if w.isNone:
      return err(string, heUnknownSymbol)
    bits.add w.get
  ok(bits, HuffmanError)

func decode*(code: HuffmanCode; bits: string): Result[string, HuffmanError] {.raises: [].} =
  ## Reads `bits` back into text: `decode(encode(t)) == t` (CODING-HUFFMAN-03). Fails with `heBadBits`
  ## on a character other than '0' or '1', on a bit that has no branch (only possible for a
  ## one-symbol code, whose only word is "0"), and when the bits stop inside a code word (CODING-HUFFMAN-07).
  var text = ""
  var at = code.root
  let lone = code.nodes[code.root].left < 0
  for b in bits:
    if b != '0' and b != '1':
      return err(string, heBadBits)
    if lone:
      if b == '1':
        return err(string, heBadBits)
      text.add code.nodes[code.root].sym
    else:
      at = if b == '0': code.nodes[at].left else: code.nodes[at].right
      if code.nodes[at].left < 0:
        text.add code.nodes[at].sym
        at = code.root
  if at != code.root:
    return err(string, heBadBits)
  ok(text, HuffmanError)
