import std/unittest
import std/options
import propcheck
import nimcs/patterns/facade

func texts(): Gen[string] {.raises: [ValueError].} =
  stringOf("abAB19 ,.-\n", 0, 30)

func refWords(text: string): seq[string] {.raises: [].} =
  ## Reference: maximal runs of [a-z0-9] after lower-casing, written independently of the module.
  var cur = ""
  for ch in text:
    let c = if ch in {'A' .. 'Z'}: char(ord(ch) + 32) else: ch
    if c in {'a' .. 'z', '0' .. '9'}:
      cur.add(c)
    elif cur.len > 0:
      result.add(cur)
      cur = ""
  if cur.len > 0:
    result.add(cur)

# SPEC: GOF-FACADE-01
test "GOF-FACADE-01 Given any text, when summarised, then words and unique counts match the reference tokenisation":
  let outcome = check(texts(), proc(t: string): bool {.raises: [CatchableError].} =
    let ws = refWords(t)
    var uniq: seq[string] = @[]
    for w in ws:
      if w notin uniq: uniq.add(w)
    let s = summarize(t)
    s.words == ws.len and s.unique == uniq.len)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-FACADE-01
test "GOF-FACADE-01 Given a sentence, when summarised, then the known summary comes back":
  let s = summarize("The cat; the DOG, the end.", 2)
  check s.words == 6
  check s.unique == 4
  check s.longest == some("the")
  check s.top == @[("the", 3), ("cat", 1)]

# SPEC: GOF-FACADE-02
test "GOF-FACADE-02 Given any text, when normalised twice, then it equals once":
  let outcome = check(texts(), proc(t: string): bool {.raises: [CatchableError].} =
    normalizeText(normalizeText(t)) == normalizeText(t))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-FACADE-03
test "GOF-FACADE-03 Given any text, when summarised before or after normalising, then the summary is equal":
  let outcome = check(texts(), proc(t: string): bool {.raises: [CatchableError].} =
    let a = summarize(t)
    let b = summarize(normalizeText(t))
    a.words == b.words and a.unique == b.unique and a.longest == b.longest and a.top == b.top)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-FACADE-04
test "GOF-FACADE-04 Given a text without word characters, when summarised, then everything is empty":
  let outcome = check(stringOf(" ,.-\n", 0, 12), proc(t: string): bool {.raises: [CatchableError].} =
    let s = summarize(t)
    s.words == 0 and s.unique == 0 and s.longest.isNone and s.top.len == 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-FACADE-04
test "GOF-FACADE-04 Given any text and topN, when summarised, then top is ordered and bounded":
  let outcome = check(pair(texts(), intIn(0, 5)), proc(p: (string, int)): bool {.raises: [CatchableError].} =
    let s = summarize(p[0], p[1])
    var ordered = s.top.len <= p[1]
    for i in 1 ..< s.top.len:
      let (a, b) = (s.top[i - 1], s.top[i])
      if not (a[1] > b[1] or (a[1] == b[1] and a[0] < b[0])): ordered = false
    ordered)
  checkpoint describe(outcome)
  check outcome.passed
