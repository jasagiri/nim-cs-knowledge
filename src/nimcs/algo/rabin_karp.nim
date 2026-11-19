## Rabin–Karp search: slide a window over the text, keeping a polynomial hash of the window
## that is updated in O(1) when the window moves, and compare characters only where the hash of
## the window equals the hash of the pattern.
##
## The modulus is explicit and validated (`HashModulus` is a distinct type built by `hashModulus`; the name differs from `number_theory.Modulus` so both modules can be imported together). A hash
## match is only a candidate: every candidate is verified against the text, so the result never
## contains a false positive whatever the modulus (STR-RK-03); a small modulus only makes the
## search slower, never wrong. Use it for many same-length patterns (hash them once) or when a
## rolling fingerprint is wanted; for one pattern with guaranteed linear time use `kmp`.

import std/options

type
  HashModulus* = distinct int
  HashParams* = object
    base*: int
    modulus*: HashModulus

const maxHashModulus*: int = 2_147_483_647
  ## 2^31 - 1: `hash * base + c` stays below 2^62, so no step overflows a 64-bit `int`.

func hashModulus*(m: int): Option[HashModulus] {.raises: [].} =
  ## A modulus must lie in 2 .. `maxHashModulus` (STR-RK-05).
  if m < 2 or m > maxHashModulus: none(HashModulus) else: some(HashModulus(m))

func `==`*(a, b: HashModulus): bool {.borrow.}
func `$`*(m: HashModulus): string {.borrow.}

func hashModulusValue*(m: HashModulus): int {.raises: [].} = int(m)

func params*(base: int; m: HashModulus): Option[HashParams] {.raises: [].} =
  ## The base must be at least 2 and below the modulus (STR-RK-05).
  if base < 2 or base >= int(m): none(HashParams)
  else: some(HashParams(base: base, modulus: m))

func hashOf*(s: openArray[char]; p: HashParams): int {.raises: [].} =
  ## Polynomial hash of `s` (STR-RK-01).
  let m = int(p.modulus)
  for c in s:
    result = (result * p.base + ord(c)) mod m

func rollingHashes*(text: string; width: int; p: HashParams): seq[int] {.raises: [].} =
  ## The hash of every window `text[i ..< i + width]`, each obtained from the previous one in
  ## O(1) (STR-RK-01). Empty when `width` < 1 or larger than the text.
  result = @[]
  if width < 1 or width > text.len:
    return
  let m = int(p.modulus)
  var lead = 1                      # base^(width-1) mod m
  for _ in 1 ..< width:
    lead = lead * p.base mod m
  var h = hashOf(text.toOpenArray(0, width - 1), p)
  result.add h
  for i in width ..< text.len:
    let drop = ord(text[i - width]) * lead mod m
    h = ((h - drop + m) mod m * p.base + ord(text[i])) mod m
    result.add h

func rkFindAll*(text, pattern: string; p: HashParams): seq[int] {.raises: [].} =
  ## Start offsets of all occurrences of `pattern`, ascending; every hash candidate is verified
  ## (STR-RK-02, STR-RK-03). An empty pattern occurs at every offset 0 .. text.len (STR-RK-04).
  result = @[]
  let w = pattern.len
  if w == 0:
    for i in 0 .. text.len:
      result.add i
    return
  if w > text.len:
    return
  let target = hashOf(pattern, p)
  let hashes = rollingHashes(text, w, p)
  for i in 0 ..< hashes.len:
    if hashes[i] == target:
      var same = true
      for j in 0 ..< w:
        if text[i + j] != pattern[j]:
          same = false
          break
      if same:
        result.add i

func rkCandidates*(text, pattern: string; p: HashParams): seq[int] {.raises: [].} =
  ## Offsets whose window hash equals the pattern hash, before verification. A superset of
  ## `rkFindAll` (STR-RK-03); exposed so a test can show that collisions are filtered out.
  result = @[]
  let w = pattern.len
  if w == 0 or w > text.len:
    return
  let target = hashOf(pattern, p)
  let hashes = rollingHashes(text, w, p)
  for i in 0 ..< hashes.len:
    if hashes[i] == target:
      result.add i
