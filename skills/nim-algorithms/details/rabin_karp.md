# Rabin–Karp search

## Intent
Slide a window over the text and keep a polynomial hash of the window that is updated in constant time as the window moves
(drop the leading character, shift, add the new one). Characters are compared only where the window's hash equals the pattern's hash, and every
such candidate is verified, so a hash collision costs time but never produces a wrong answer.

## Use when / avoid when
- Use it to search for many patterns of the same length (hash them once and look windows up), and for rolling fingerprints in general.
- Use `kmp.md` or `z_algorithm.md` when worst-case linear time for one pattern is required: Rabin–Karp degrades to quadratic when many windows collide.
- Avoid skipping the verification step to "save time": it turns a probabilistic filter into a wrong answer.

## Nim shape
The modulus is explicit: `HashModulus` is a `distinct int` built by `hashModulus(m)`, which returns `Option[HashModulus]` (2..2^31-1, so no
intermediate product overflows). `params(base, m)` validates the base. `rkFindAll` returns verified offsets; `rkCandidates` returns the offsets
before verification so the filter can be inspected. Module: `src/nimcs/algo/rabin_karp.nim`.

```nim
import std/options
import nimcs/algo/rabin_karp

let p = params(257, hashModulus(1_000_003).get).get
doAssert rkFindAll("abracadabra", "abra", p) == @[0, 7]
doAssert hashOf("abra", p) == rollingHashes("abracadabra", 4, p)[0]
doAssert hashModulus(1).isNone
```

A tiny modulus shows the verification at work:

```nim
import nimcs/algo/rabin_karp
import std/options

let p = params(2, hashModulus(3).get).get
doAssert rkCandidates("abbabab", "abb", p).len >= rkFindAll("abbabab", "abb", p).len
doAssert rkFindAll("abbabab", "abb", p) == @[0]
```

## Laws and invariants
- Every rolling window hash equals a fresh hash of that window (STR-RK-01).
- With a realistic modulus the results equal the naive search (STR-RK-02).
- With a tiny modulus the candidates are a superset of the results and the results still equal the naive search: no false positives (STR-RK-03).
- An empty pattern occurs at every offset; a pattern longer than the text occurs nowhere (STR-RK-04).
- An invalid modulus or base gives `none` (STR-RK-05).

## Complexity
Expected O(text.len + pattern.len) with a good modulus; worst case O(text.len * pattern.len) when collisions are frequent. Space O(text.len) in this version, which materialises the window hashes.

## Pitfalls
Subtracting the dropped character without adding the modulus can go negative, and a negative remainder is a different hash:

```nim bad
h = ((h - ord(text[i - width]) * lead) * base + ord(text[i])) mod m   # h may be negative
```

Fix: `((h - drop + m) mod m * base + ord(text[i])) mod m`, with `drop` already reduced mod `m`. Also, choose a modulus whose
residue products fit the integer type (the reason for the 2^31-1 bound), and always verify candidates.

## Related
`kmp.md`, `z_algorithm.md`, `number_theory.md` (modular arithmetic), `suffix_array.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `61811291625a13a9` Algorithms for Competitive Programming
- `6f359b1814ec2eeb` Princeton University Algorithms, Part 2
