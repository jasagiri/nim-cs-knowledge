# Edit distance

## Intent
The edit (Levenshtein) distance is the fewest single-character insertions, deletions and substitutions that
turn one string into another. The cell for a pair of prefixes is one more than the cheapest of three smaller
cells, and the path back through the table is an edit script.

## Use when / avoid when
- Use it for spelling suggestions, fuzzy search and measuring how different two short strings are.
- Use `lcs.md` for a diff that never substitutes: insert/delete distance is `len a + len b - 2 * lcsLength`.
- Avoid it on long inputs (quadratic) when an approximate or banded variant would do.

## Nim shape
Edits are an object variant `EditOp` with an exhaustive `case`: keep, replace (before and after), insert, delete.
`editScript` returns the operations, and `applyScript` replays them, so the script can be checked. Module: `src/nimcs/algo/edit_distance.nim`.

```nim
import std/options
import nimcs/algo/edit_distance

let script = editScript("kitten", "sitting")
doAssert editDistance("kitten", "sitting") == 3
doAssert cost(script) == 3
doAssert applyScript("kitten", script) == some("sitting")
doAssert applyScript("kitten", [keep('x')]).isNone
```

## Laws and invariants
- d(a, a) = 0, and d(a, b) = 0 only if a = b (DP-EDIT-02).
- Symmetry: d(a, b) = d(b, a) (DP-EDIT-03).
- Triangle inequality, d(a, b) <= max(len a, len b) and d(a, b) >= abs(len a - len b) (DP-EDIT-04).
- The script costs exactly the distance and is deterministic (DP-EDIT-05).
- Applying the script to `a` gives `b`; a script that does not fit gives `none` (DP-EDIT-06).
- Hand-worked values: kitten/sitting is 3 (DP-EDIT-01).

## Complexity
Time O(len a * len b). Space O(len b) for the distance (two rows), O(len a * len b) for the script.

## Pitfalls
Initialising only the first cell leaves the borders at zero and makes every distance too small:

```nim bad
var table = newSeq[int]((a.len + 1) * (b.len + 1))   # borders are 0, not j and i
```

Fix: row 0 is `0, 1, 2, ...` (insert j characters) and column 0 likewise (delete i characters). Also, give the three
moves the same tie-break order every time, otherwise two runs may print different (equally cheap) scripts.

## Related
`lcs.md`, `memoization.md`, `kmp.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `a8882bbba7213b23` Algorithms Notes for Professionals
- `b609569e40e49e47` Analysis of Algorithms (CSE 373)
- `63ad3e14455a34af` Competitive Programmer's Handbook
- `e8a751ae9f8ed52b` Learning Algorithm
