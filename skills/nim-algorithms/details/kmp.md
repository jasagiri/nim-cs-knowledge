# Knuth–Morris–Pratt search

## Intent
Find every occurrence of a pattern in a text without ever moving backwards in the text. A failure table
records, for each prefix of the pattern, the length of its longest proper border (a prefix that is also a suffix); after a mismatch the
search falls back to that border instead of starting over.

## Use when / avoid when
- Use it when worst-case linear time matters: streaming input, adversarial text, repeated patterns such as "aaaa...ab".
- Use `z_algorithm.md` for the same answers with a simpler invariant, `rabin_karp.md` for many patterns of one length, `suffix_array.md` when the text is fixed and queried many times.
- Avoid it for a one-off search over short strings; the standard library's `find` is enough.

## Nim shape
`kmpFailure(pattern)` builds the table; `kmpFindAll(text, pattern)` returns the 0-based start offsets, ascending,
overlapping matches included. An empty pattern occurs at every offset 0..text.len. Module: `src/nimcs/algo/kmp.nim`.

```nim
import nimcs/algo/kmp

doAssert kmpFailure("abab") == @[0, 0, 1, 2]
doAssert kmpFindAll("abababa", "aba") == @[0, 2, 4]
doAssert kmpFindAll("abc", "").len == 4
```

## Laws and invariants
- `kmpFailure(p)[i]` is the longest proper border of `p[0..i]` (STR-KMP-01).
- `kmpFindAll` returns the same positions as the naive quadratic search (STR-KMP-02).
- Overlapping occurrences are all reported, in ascending order (STR-KMP-03).
- The empty pattern occurs at every offset including the end (STR-KMP-04).

## Complexity
Time O(text.len + pattern.len): the pattern index `k` rises at most once per text character, and each fall-back lowers it, so total fall-backs are bounded by total rises. Space O(pattern.len).

## Pitfalls
After a full match, restarting from zero skips overlapping occurrences:

```nim bad
if k == pattern.len:
  result.add i - pattern.len + 1
  k = 0                     # misses "aa" at offset 1 in "aaa"
```

Fix: continue from the border, `k = fail[k - 1]`, as `kmpFindAll` does. A second trap is building the table with a
fall-back loop that compares against `pattern[k]` before checking `k > 0`, which indexes out of range on mismatch at the start.

## Related
`z_algorithm.md`, `rabin_karp.md`, `suffix_array.md`, `lcs.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `61811291625a13a9` Algorithms for Competitive Programming
- `a8882bbba7213b23` Algorithms Notes for Professionals
- `5ea7cdc2c5670fd7` Data Structures and Algorithms
- `e8a751ae9f8ed52b` Learning Algorithm
- `6f359b1814ec2eeb` Princeton University Algorithms, Part 2
