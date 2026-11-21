import std/[algorithm, options, sequtils, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/huffman

proc texts(): Gen[string] {.raises: [ValueError].} =
  stringOf("abcdefgh", 1, 60)

func build(text: string): HuffmanCode {.raises: [].} =
  ## A non-empty text always gives a valid frequency list, so building cannot fail.
  buildCode(frequencies(text)).value

func weightedLength(code: HuffmanCode; freqs: seq[(char, int)]): int {.raises: [].} =
  for (c, f) in freqs:
    result += f * code.wordOf(c).get.len

func mergeCost(freqs: seq[(char, int)]): int {.raises: [].} =
  ## The optimal cost computed another way: repeatedly merge the two smallest weights and add up
  ## the merged weights (no tree, no tie-break needed because only the sum matters).
  var weights: seq[int]
  for (_, f) in freqs:
    weights.add f
  while weights.len > 1:
    weights.sort
    let merged = weights[0] + weights[1]
    result += merged
    weights = weights[2 .. ^1] & @[merged]

# SPEC: CODING-HUFFMAN-01
test "CODING-HUFFMAN-01 Given the frequencies a:5 b:2 c:1 d:1, when the code is built, then the words are the hand-derived ones":
  let code = buildCode(@[('d', 1), ('a', 5), ('c', 1), ('b', 2)])
  check code.isOk
  check code.value.codeWords == @[('a', "1"), ('b', "00"), ('c', "010"), ('d', "011")]

# SPEC: CODING-HUFFMAN-01
test "CODING-HUFFMAN-01 Given a frequency list in any order, when the code is built, then the code does not depend on the order":
  let outcome = check(texts(), proc(t: string): bool {.raises: [CatchableError].} =
    let freqs = frequencies(t)
    let a = buildCode(freqs).value.codeWords
    let b = buildCode(freqs.reversed).value.codeWords
    let c = buildCode(freqs.sortedByIt(it[1])).value.codeWords
    a == b and a == c)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: CODING-HUFFMAN-02
test "CODING-HUFFMAN-02 Given any text, when its code is built, then no code word begins another":
  let outcome = check(texts(), proc(t: string): bool {.raises: [CatchableError].} =
    let code = build(t)
    var seen: seq[string]
    for (_, w) in code.codeWords:
      seen.add w
    code.isPrefixFree and seen.deduplicate.len == seen.len)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: CODING-HUFFMAN-03
test "CODING-HUFFMAN-03 Given any text, when encoded and decoded with its own code, then the text comes back":
  let outcome = check(texts(), proc(t: string): bool {.raises: [CatchableError].} =
    let code = build(t)
    let bits = code.encode(t)
    bits.isOk and code.decode(bits.value) == ok(t, HuffmanError))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: CODING-HUFFMAN-03
test "CODING-HUFFMAN-03 Given the empty text, when encoded and decoded, then both are empty":
  let code = buildCode(@[('a', 1), ('b', 1)]).value
  check code.encode("") == ok("", HuffmanError)
  check code.decode("") == ok("", HuffmanError)

# SPEC: CODING-HUFFMAN-04
test "CODING-HUFFMAN-04 Given any frequencies, when the code is built, then its cost equals the independent merge cost":
  let outcome = check(texts(), proc(t: string): bool {.raises: [CatchableError].} =
    let freqs = frequencies(t)
    if freqs.len < 2: return true
    build(t).weightedLength(freqs) == mergeCost(freqs))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: CODING-HUFFMAN-04
test "CODING-HUFFMAN-04 Given two or more symbols, when the code is built, then the words fill the code space and rarer symbols are not shorter":
  let outcome = check(texts(), proc(t: string): bool {.raises: [CatchableError].} =
    let freqs = frequencies(t)
    if freqs.len < 2: return true
    let code = build(t)
    var longest = 0
    for (_, w) in code.codeWords:
      longest = max(longest, w.len)
    var space = 0                                   # Kraft sum scaled by 2^longest
    for (_, w) in code.codeWords:
      space += 1 shl (longest - w.len)
    if space != 1 shl longest: return false
    for (a, fa) in freqs:
      for (b, fb) in freqs:
        if fa > fb and code.wordOf(a).get.len > code.wordOf(b).get.len: return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: CODING-HUFFMAN-05
test "CODING-HUFFMAN-05 Given an empty list, a bad frequency, a repeated symbol or an overflowing total, when built, then each has its own error":
  check buildCode(newSeq[(char, int)]()) == err(HuffmanCode, heEmptyInput)
  check buildCode(@[('a', 0), ('b', 1)]) == err(HuffmanCode, heBadFrequency)
  check buildCode(@[('a', -3)]) == err(HuffmanCode, heBadFrequency)
  check buildCode(@[('a', 1), ('a', 2)]) == err(HuffmanCode, heDuplicateSymbol)
  check buildCode(@[('a', high(int)), ('b', 1)]) == err(HuffmanCode, heWeightOverflow)

# SPEC: CODING-HUFFMAN-06
test "CODING-HUFFMAN-06 Given a character outside the code, when encoding, then the error names an unknown symbol":
  let code = buildCode(@[('a', 3), ('b', 1)]).value
  check code.encode("abz") == err(string, heUnknownSymbol)
  check code.wordOf('z').isNone

# SPEC: CODING-HUFFMAN-07
test "CODING-HUFFMAN-07 Given bits that are not binary or stop inside a word, when decoding, then the error says bad bits":
  let code = buildCode(@[('a', 5), ('b', 2), ('c', 1), ('d', 1)]).value
  check code.decode("0x") == err(string, heBadBits)
  check code.decode("01") == err(string, heBadBits)       # "01" is the start of c or d
  check code.decode("1" & "00") == ok("ab", HuffmanError)

# SPEC: CODING-HUFFMAN-08
test "CODING-HUFFMAN-08 Given a single symbol, when coded, then its word is 0 and only 0 bits decode":
  let code = buildCode(@[('x', 7)]).value
  check code.codeWords == @[('x', "0")]
  check code.encode("xxx") == ok("000", HuffmanError)
  check code.decode("000") == ok("xxx", HuffmanError)
  check code.decode("01") == err(string, heBadBits)
  check code.isPrefixFree
