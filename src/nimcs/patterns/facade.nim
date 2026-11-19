## Facade as a module that exports a small API over several private steps.
##
## The OO pattern puts one simple class in front of a set of subsystem classes. In Nim the module
## boundary is the facade: the steps (`tokenize`, `countWords`, ...) are not exported, and the
## exported surface is `normalizeText` and `summarize`. Use it when callers need one or two
## answers and should not know the order or number of internal steps. No class is needed.

import std/[algorithm, options, tables]

type
  Summary* = object
    words*: int
    unique*: int
    longest*: Option[string]
    top*: seq[(string, int)]

func isWordChar(c: char): bool {.raises: [].} =
  c in {'a' .. 'z', '0' .. '9'}

func lowerAscii(c: char): char {.raises: [].} =
  if c in {'A' .. 'Z'}: char(ord(c) + 32) else: c

func normalizeText*(text: string): string {.raises: [].} =
  ## Lower-cases ASCII letters, turns every other character into a space, collapses runs of
  ## spaces and trims. Idempotent.
  var pendingSpace = false
  for raw in text:
    let c = lowerAscii(raw)
    if isWordChar(c):
      if pendingSpace and result.len > 0:
        result.add(' ')
      pendingSpace = false
      result.add(c)
    else:
      pendingSpace = true

func tokenize(normalized: string): seq[string] =
  var current = ""
  for c in normalized:
    if c == ' ':
      if current.len > 0:
        result.add(current)
        current = ""
    else:
      current.add(c)
  if current.len > 0:
    result.add(current)

func countWords(words: seq[string]): seq[(string, int)] =
  ## Sorted by count descending, then word ascending, so the order never depends on hashing.
  var counts = initTable[string, int]()
  for w in words:
    counts[w] = counts.getOrDefault(w, 0) + 1
  for w, n in counts:
    result.add((w, n))
  result.sort(proc(a, b: (string, int)): int =
    if a[1] != b[1]: cmp(b[1], a[1]) else: cmp(a[0], b[0]))

func summarize*(text: string; topN: int = 3): Summary {.raises: [].} =
  let words = tokenize(normalizeText(text))
  let counts = countWords(words)
  var longest = none(string)
  for w in words:
    if longest.isNone or w.len > longest.get.len:
      longest = some(w)
  Summary(words: words.len, unique: counts.len, longest: longest,
          top: counts[0 ..< min(max(topN, 0), counts.len)])
