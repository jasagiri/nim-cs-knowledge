import std/[unittest, options]
import propcheck
import nimcs/patterns/seam

const Known = ["apple", "pear", "fig"]

func skuGen(): Gen[seq[string]] {.raises: [ValueError].} = seqOf(pick(Known), 0, 6)

# SPEC: PAT-SEAM-01
test "PAT-SEAM-01 Given any known SKUs, when totalled through the default seam, then the total is the hard-wired routine's":
  let outcome = check(skuGen(), proc(skus: seq[string]): bool {.raises: [CatchableError].} =
    total(defaultSeam(), skus) == ok(legacyTotal(skus), PriceError))
  checkpoint describe(outcome)
  check outcome.passed
  check legacyTotal(@["apple", "pear"]) == 270
  check legacyTotal(@["apple", "pear", "fig"]) == 570 - 57   # a tenth off from the third line

# SPEC: PAT-SEAM-02
test "PAT-SEAM-02 Given any prices supplied as the seam, when known SKUs are totalled, then the total is the sum of the prices with the discount":
  let outcome = check(pair(seqOf(intIn(0, 9999), 3, 3), skuGen()),
      proc(x: (seq[int], seq[string])): bool {.raises: [CatchableError].} =
    let (cents, skus) = x
    let fake: Seam = proc(sku: string): Option[int] {.noSideEffect, raises: [].} =
      for i, k in Known:
        if k == sku: return some(cents[i])
      none(int)
    var sum = 0
    for s in skus:
      for i, k in Known:
        if k == s: sum += cents[i]
    let expected = if skus.len >= 3: sum - sum div 10 else: sum
    total(fake, skus) == ok(expected, PriceError))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-SEAM-03
test "PAT-SEAM-03 Given a SKU the seam does not know, when totalled, then the error names the first such SKU":
  let outcome = check(pair(skuGen(), pair(intIn(0, 6), skuGen())),
      proc(x: (seq[string], (int, seq[string]))): bool {.raises: [CatchableError].} =
    let (head, (extra, tail)) = x
    let skus = head & @["ghost" & $extra] & tail & @["phantom"]
    let r = total(defaultSeam(), skus)
    r.isErr and r.error.unknownSku == "ghost" & $extra)
  checkpoint describe(outcome)
  check outcome.passed
  check legacyTotal(@["ghost"]) == 0   # what the seam version refuses to do
  check total(defaultSeam(), @["ghost"]).isErr

# SPEC: PAT-SEAM-04
test "PAT-SEAM-04 Given pins from a routine, when checked, then they hold for it and name the first input where a changed routine differs":
  let outcome = check(seqOf(skuGen(), 0, 6), proc(inputs: seq[seq[string]]): bool {.raises: [CatchableError].} =
    let pins = pin(legacyTotal, inputs)
    let viaSeam: Total = proc(skus: seq[string]): int {.noSideEffect, raises: [].} =
      total(defaultSeam(), skus).valueOr(0)
    let changed: Total = proc(skus: seq[string]): int {.noSideEffect, raises: [].} =
      legacyTotal(skus) + (if "fig" in skus: 1 else: 0)
    var firstFig = -1
    for i, input in inputs:
      if "fig" in input and firstFig < 0: firstFig = i
    pins.holds(legacyTotal) and pins.holds(viaSeam) and
      (if firstFig < 0: pins.holds(changed)
       else: pins.firstDifference(changed) == some(firstFig) and not pins.holds(changed)))
  checkpoint describe(outcome)
  check outcome.passed
