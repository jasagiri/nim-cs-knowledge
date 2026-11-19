## The Z-array: for every position i, the length of the longest common prefix of the string and
## its suffix starting at i, computed in linear time by reusing the rightmost match window.
##
## Use it for pattern search (`zFindAll`), borders and periods of a string. It answers the same
## questions as `kmp` with a simpler invariant (the window `[l, r)` is a match of the prefix),
## which is why it is a good first linear-time string algorithm to learn.
##
## Convention: `z[0]` is the length of the whole string (the suffix at 0 is the string itself).

func zArray*(s: string): seq[int] {.raises: [].} =
  ## `result[i]` = length of the longest common prefix of `s` and `s[i .. ^1]` (STR-ZALGO-01, STR-ZALGO-02).
  result = newSeq[int](s.len)
  if s.len == 0:
    return
  result[0] = s.len
  var l = 0
  var r = 0   # s[l ..< r] equals s[0 ..< r - l]
  for i in 1 ..< s.len:
    var k = 0
    if i < r:
      k = min(r - i, result[i - l])
    while i + k < s.len and s[k] == s[i + k]:
      inc k
    result[i] = k
    if i + k > r:
      l = i
      r = i + k

func zFindAll*(text, pattern: string): seq[int] {.raises: [].} =
  ## Start offsets of all occurrences of `pattern` in `text`, ascending. An empty pattern occurs
  ## at every offset 0 .. text.len (STR-ZALGO-03, STR-ZALGO-04).
  ##
  ## Z is computed on `pattern & text` with no separator: a value `z[i] >= pattern.len` at
  ## i >= pattern.len means `s[i ..< i + m]` equals the pattern, and that range lies inside `text`.
  result = @[]
  let m = pattern.len
  if m == 0:
    for i in 0 .. text.len:
      result.add i
    return
  let z = zArray(pattern & text)
  for i in m ..< z.len:
    if z[i] >= m:
      result.add i - m
