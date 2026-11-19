# Z-algorithm

## Intent
For every position i of a string, compute the length of the longest common prefix of the string and the
suffix starting at i. The algorithm keeps the rightmost window `[l, r)` that matches a prefix and copies
earlier answers inside it, so no character is compared twice.

## Use when / avoid when
- Use it for substring search, for finding borders and the smallest period of a string, and as the simplest linear-time string algorithm to implement correctly.
- Use `kmp.md` when the text arrives as a stream (the Z-array needs the whole string up front).
- Use `suffix_array.md` when many different patterns are searched in one text.

## Nim shape
`zArray(s)` returns the array (entry 0 is the length of `s` by convention). `zFindAll(text, pattern)` builds the array of
`pattern & text`: a value of at least `pattern.len` at a position inside the text part means the pattern occurs there. No separator character
is needed, because such a value already proves the first `pattern.len` characters match the pattern. Module: `src/nimcs/algo/z_algorithm.nim`.

```nim
import nimcs/algo/z_algorithm

doAssert zArray("aabxaab") == @[7, 1, 0, 0, 3, 1, 0]
doAssert zFindAll("abababa", "aba") == @[0, 2, 4]
doAssert zFindAll("abc", "") == @[0, 1, 2, 3]
```

## Laws and invariants
- `zArray(s)[i]` equals the common prefix length of `s` and `s[i..]` (STR-ZALGO-01).
- `zArray(s)[0] == s.len`; the empty string gives an empty array (STR-ZALGO-02).
- `zFindAll` equals the naive search on any text and pattern (STR-ZALGO-03).
- The empty pattern occurs at every offset including the end (STR-ZALGO-04).

## Complexity
Time O(n) for the array and O(text.len + pattern.len) for the search; the pointer `r` only moves right. Space O(n).

## Pitfalls
Ignoring the window and recomputing each entry from scratch is quadratic on inputs such as "aaaa...a":

```nim bad
for i in 1 ..< s.len:
  var k = 0
  while i + k < s.len and s[k] == s[i + k]: inc k   # restarts at 0 every time
  result[i] = k
```

Fix: start from `min(r - i, z[i - l])` when i lies inside the window, as `zArray` does, and extend only beyond `r`.
Another pitfall: reading `z[0]` as 0 in a formula that expects the full length.

## Related
`kmp.md`, `rabin_karp.md`, `suffix_array.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `61811291625a13a9` Algorithms for Competitive Programming
- `63ad3e14455a34af` Competitive Programmer's Handbook
