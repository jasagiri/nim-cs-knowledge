## Knuth–Morris–Pratt substring search: never move backwards in the text.
##
## The failure table says, for each prefix of the pattern, how long its longest proper border is
## (a prefix that is also a suffix). After a mismatch the search resumes from that border instead of
## from scratch, so the work is linear in `text.len + pattern.len`. Use it for one pattern over
## streaming or adversarial text; `z_algorithm` gives the same answers by another route, and
## `rabin_karp` is the choice for many patterns of one length.
##
## Positions are 0-based start offsets of every occurrence, overlapping ones included. An empty
## pattern occurs at every offset 0 .. text.len (STR-KMP-04).

func kmpFailure*(pattern: string): seq[int] {.raises: [].} =
  ## `result[i]` is the length of the longest proper border of `pattern[0 .. i]` (STR-KMP-01).
  result = newSeq[int](pattern.len)
  var k = 0
  for i in 1 ..< pattern.len:
    while k > 0 and pattern[i] != pattern[k]:
      k = result[k - 1]
    if pattern[i] == pattern[k]:
      inc k
    result[i] = k

func kmpFindAll*(text, pattern: string): seq[int] {.raises: [].} =
  ## Start offsets of all occurrences of `pattern` in `text`, ascending (STR-KMP-02, STR-KMP-03).
  result = @[]
  if pattern.len == 0:
    for i in 0 .. text.len:
      result.add i
    return
  let fail = kmpFailure(pattern)
  var k = 0
  for i in 0 ..< text.len:
    while k > 0 and text[i] != pattern[k]:
      k = fail[k - 1]
    if text[i] == pattern[k]:
      inc k
    if k == pattern.len:
      result.add i - pattern.len + 1
      k = fail[k - 1]
