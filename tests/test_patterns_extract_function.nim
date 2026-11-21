import std/unittest
import propcheck
import nimcs/patterns/extract_function

proc linesGen(): Gen[seq[(int, int)]] {.raises: [ValueError].} =
  seqOf(pair(intIn(0, 5000), intIn(0, 20)), 0, 8)

func toLines(xs: seq[(int, int)]): seq[Line] {.raises: [].} =
  for x in xs: result.add Line(unitPrice: x[0], quantity: x[1])

# SPEC: PAT-EXTRACTFUNCTION-01
test "PAT-EXTRACTFUNCTION-01 Given any order, when summarised before and after extraction, then the text is identical":
  let outcome = check(linesGen(), proc(xs: seq[(int, int)]): bool {.raises: [CatchableError].} =
    let ls = toLines(xs)
    ls.summaryBefore == ls.summary)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-EXTRACTFUNCTION-02
test "PAT-EXTRACTFUNCTION-02 Given two lists, when joined, then the subtotal of the join is the sum of the subtotals":
  let outcome = check(pair(linesGen(), linesGen()),
      proc(x: (seq[(int, int)], seq[(int, int)])): bool {.raises: [CatchableError].} =
    let a = toLines(x[0])
    let b = toLines(x[1])
    (a & b).subtotal == a.subtotal + b.subtotal and newSeq[Line]().subtotal == 0)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-EXTRACTFUNCTION-03
test "PAT-EXTRACTFUNCTION-03 Given any subtotal, when the discount is asked, then it is zero below the threshold and a fixed share from it":
  let outcome = check(intIn(0, 40000), proc(s: int): bool {.raises: [CatchableError].} =
    if s < BulkThreshold: s.discountOf == 0
    else: s.discountOf == s * BulkPercent div 100 and s.discountOf <= s)
  checkpoint describe(outcome)
  check outcome.passed
  check (BulkThreshold - 1).discountOf == 0
  check BulkThreshold.discountOf == 500

# SPEC: PAT-EXTRACTFUNCTION-04
test "PAT-EXTRACTFUNCTION-04 Given any order, when summarised, then the parts add up and the tax is rounded down":
  let outcome = check(linesGen(), proc(xs: seq[(int, int)]): bool {.raises: [CatchableError].} =
    let s = toLines(xs).summarize
    s.total == s.subtotal - s.discount + s.tax and
      s.tax == (s.subtotal - s.discount).taxOf and
      s.tax * 100 <= (s.subtotal - s.discount) * TaxPercent)
  checkpoint describe(outcome)
  check outcome.passed
  check taxOf(19) == 1
  check summarize(@[Line(unitPrice: 6000, quantity: 2)]) ==
    Summary(subtotal: 12000, discount: 600, tax: 1140, total: 12540)
