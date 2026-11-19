import std/[unittest, strutils]
import propcheck
import nimcs/patterns/template_method

func ints(): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(-9, 9), 0, 12)

func isEven(x: int): bool {.raises: [].} = x mod 2 == 0
func shoutFooter(n: int): string {.raises: [].} = "DONE " & $n

# SPEC: GOF-TEMPLATE-01
test "GOF-TEMPLATE-01 Given any items, when rendered with the default steps, then the first line is the header and the last is the footer":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let lines = render(xs, defaultSteps[int]()).splitLines
    lines[0] == "Report (" & $xs.len & " items)" and lines[^1] == "end")
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-TEMPLATE-02
test "GOF-TEMPLATE-02 Given a keep step, when rendered, then there is one row per kept item between header and footer":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let steps = defaultSteps[int]().withKeep(isEven)
    let lines = render(xs, steps).splitLines
    var evens = 0
    for x in xs:
      if isEven(x): inc evens
    lines.len == evens + 2 and lines[0] == "Report (" & $evens & " items)")
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-TEMPLATE-03
test "GOF-TEMPLATE-03 Given a variant footer, when rendered, then only the footer line differs from the default":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let base = render(xs, defaultSteps[int]()).splitLines
    let changed = render(xs, defaultSteps[int]().withFooter(shoutFooter)).splitLines
    base.len == changed.len and base[0 ..< base.len - 1] == changed[0 ..< changed.len - 1] and
      changed[^1] == "DONE " & $xs.len)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-TEMPLATE-04
test "GOF-TEMPLATE-04 Given the same items and steps, when rendered twice, then the text is identical":
  let outcome = check(ints(), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    render(xs, csvSteps[int]()) == render(xs, csvSteps[int]()))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-TEMPLATE-05
test "GOF-TEMPLATE-05 Given two variants, when rendered, then both share the skeleton and differ in the steps":
  check render([5, 8], defaultSteps[int]()) == "Report (2 items)\n1. 5\n2. 8\nend"
  check render([5, 8], csvSteps[int]()) == "index,value\n0,5\n1,8\ntotal,2"
  check render(newSeq[int](), csvSteps[int]()) == "index,value\ntotal,0"

# SPEC: GOF-TEMPLATE-06
test "GOF-TEMPLATE-06 Given a row step and a keep step, when rendered, then row indices count kept items from zero":
  let steps = defaultSteps[int]()
    .withKeep(isEven)
    .withRow(proc(item: int; index: int): string {.noSideEffect, raises: [].} = $index & ":" & $item)
  check render([1, 2, 3, 4, 6], steps) == "Report (3 items)\n0:2\n1:4\n2:6\nend"

# A tiny RFC 4180 reader for the rows "index,field\n" that csvSteps writes (header already
# included, footer already removed). A row ends at the newline that follows its closing quote, or
# at the first newline of an unquoted field.
func readFields(text: string): seq[string] {.raises: [].} =
  var i = 0
  while i < text.len and text[i] != '\n': inc i   # header line
  inc i
  while i < text.len:
    while i < text.len and text[i] != ',': inc i   # the index column
    inc i
    var field = ""
    if i < text.len and text[i] == '"':
      inc i
      while i < text.len:
        if text[i] == '"':
          if i + 1 < text.len and text[i + 1] == '"':
            field.add '"'
            i += 2
          else:
            inc i
            break
        else:
          field.add text[i]
          inc i
    else:
      while i < text.len and text[i] != '\n':
        field.add text[i]
        inc i
    result.add field
    inc i   # the newline that ends the row

# SPEC: GOF-TEMPLATE-07
test "GOF-TEMPLATE-07 Given strings with commas, quotes and newlines, when rendered as CSV, then a CSV reader recovers each field":
  let outcome = check(seqOf(stringOf("ab,\"\n\r ", 0, 6), 0, 6), proc(xs: seq[string]): bool {.raises: [CatchableError].} =
    let text = render(xs, csvSteps[string]())
    let footer = "total," & $xs.len
    text.endsWith(footer) and readFields(text[0 ..< text.len - footer.len]) == xs)
  checkpoint describe(outcome)
  check outcome.passed
  check render(["a,b", "say \"hi\"", "plain"], csvSteps[string]()) ==
    "index,value\n0,\"a,b\"\n1,\"say \"\"hi\"\"\"\n2,plain\ntotal,3"
