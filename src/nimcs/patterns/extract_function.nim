## Extract function: cut a long routine at the seams where it computes a named thing.
##
## `summaryBefore` totals an order, applies a bulk discount, adds tax and formats a line, all in
## one body with four local variables that each step reads. `summary` is the same behaviour as a
## sequence of small functions (`subtotal`, `discountOf`, `taxOf`, `render`), each of which takes
## what it needs as arguments and returns one value, so each has a name, a signature and a law
## of its own. Extract when a comment would otherwise say "now compute the discount", when a block
## has one input and one output, or when you want to test one step without the others. A block
## that reads and writes many locals is not ready: introduce a parameter object first
## (`introduce_parameter_object`). Money is whole yen; tax is rounded down.

type
  Line* = object
    unitPrice*: int
    quantity*: int

  Summary* = object
    ## The parts, so a caller can use them without parsing text.
    subtotal*: int
    discount*: int
    tax*: int
    total*: int

const
  BulkThreshold* = 10000   ## subtotal from which the discount applies
  BulkPercent* = 5
  TaxPercent* = 10

func summaryBefore*(lines: openArray[Line]): string {.raises: [].} =
  ## Before: one body, four phases separated by comments.
  # subtotal
  var sub = 0
  for l in lines:
    sub += l.unitPrice * l.quantity
  # discount
  var disc = 0
  if sub >= BulkThreshold:
    disc = sub * BulkPercent div 100
  # tax
  let taxed = (sub - disc) * TaxPercent div 100
  # format
  "subtotal " & $sub & ", discount " & $disc & ", tax " & $taxed & ", total " & $(sub - disc + taxed)

func subtotal*(lines: openArray[Line]): int {.raises: [].} =
  ## Sum of `unitPrice * quantity`; additive over concatenation of lists.
  for l in lines: result += l.unitPrice * l.quantity

func discountOf*(subtotal: int): int {.raises: [].} =
  ## Bulk discount: a percentage once the subtotal reaches the threshold, else nothing.
  if subtotal >= BulkThreshold: subtotal * BulkPercent div 100 else: 0

func taxOf*(amount: int): int {.raises: [].} =
  ## Tax on an amount already discounted, rounded down.
  amount * TaxPercent div 100

func summarize*(lines: openArray[Line]): Summary {.raises: [].} =
  let sub = lines.subtotal
  let disc = sub.discountOf
  let tax = (sub - disc).taxOf
  Summary(subtotal: sub, discount: disc, tax: tax, total: sub - disc + tax)

func render*(s: Summary): string {.raises: [].} =
  "subtotal " & $s.subtotal & ", discount " & $s.discount & ", tax " & $s.tax & ", total " & $s.total

func summary*(lines: openArray[Line]): string {.raises: [].} =
  ## After: the same text as `summaryBefore`, as a pipeline of named steps.
  lines.summarize.render
