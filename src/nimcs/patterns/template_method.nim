## Template Method: the skeleton is a higher-order function and the steps are its arguments.
##
## The OO pattern fixes an algorithm's order in a base-class method and lets subclasses override
## individual steps. Nim needs no base class: the skeleton is a `func` that takes the varying
## steps as values, and a "subclass" is a `ReportSteps` value in which some fields differ from
## `defaultSteps`. The skeleton's order (header, filtered rows, footer) cannot be broken by a
## variant because variants never get to write the skeleton. Use it when several variants share
## a fixed sequence of steps. Here: a line-oriented text report, rendered as a plain list or as
## CSV with the same skeleton.

import std/strutils

type
  ReportSteps*[T] = object
    ## The varying parts. Each step is pure.
    header*: proc(shown: int): string {.noSideEffect, raises: [].}
    keep*: proc(item: T): bool {.noSideEffect, raises: [].}
    row*: proc(item: T; index: int): string {.noSideEffect, raises: [].}
    footer*: proc(shown: int): string {.noSideEffect, raises: [].}

func defaultSteps*[T](): ReportSteps[T] {.raises: [].} =
  ## Header "Report (n items)", every item kept, row "<index>. <item>", footer "end".
  ## Rows use `$` on the item.
  ReportSteps[T](
    header: proc(shown: int): string {.noSideEffect, raises: [].} = "Report (" & $shown & " items)",
    keep: proc(item: T): bool {.noSideEffect, raises: [].} = true,
    row: proc(item: T; index: int): string {.noSideEffect, raises: [].} = $(index + 1) & ". " & $item,
    footer: proc(shown: int): string {.noSideEffect, raises: [].} = "end")

func render*[T](items: openArray[T]; steps: ReportSteps[T]): string {.raises: [].} =
  ## The template method. Fixed order: header, then one row per kept item, then footer, one per
  ## line. `shown` passed to header and footer is the number of kept items. Indices count kept items
  ## from 0.
  var kept: seq[T]
  for it in items:
    if steps.keep(it): kept.add it
  var lines = @[steps.header(kept.len)]
  for i, it in kept: lines.add steps.row(it, i)
  lines.add steps.footer(kept.len)
  lines.join("\n")

func withFooter*[T](s: ReportSteps[T]; footer: proc(shown: int): string {.noSideEffect, raises: [].}): ReportSteps[T] {.raises: [].} =
  ## A variant: same steps, different footer.
  result = s
  result.footer = footer

func withKeep*[T](s: ReportSteps[T]; keep: proc(item: T): bool {.noSideEffect, raises: [].}): ReportSteps[T] {.raises: [].} =
  result = s
  result.keep = keep

func withRow*[T](s: ReportSteps[T]; row: proc(item: T; index: int): string {.noSideEffect, raises: [].}): ReportSteps[T] {.raises: [].} =
  result = s
  result.row = row

func csvField*(s: string): string {.raises: [].} =
  ## RFC 4180 quoting: a field containing a comma, a double quote, CR or LF is wrapped in double
  ## quotes and its quotes are doubled; any other field is written as is.
  var needs = false
  for c in s:
    if c in {',', '"', '\r', '\n'}: needs = true
  if not needs: return s
  result = "\""
  for c in s:
    if c == '"': result.add "\"\""
    else: result.add c
  result.add '"'

func csvSteps*[T](): ReportSteps[T] {.raises: [].} =
  ## Variant: header "index,value", rows "<index>,<item>" with the item quoted by `csvField`,
  ## footer "total,<n>". A quoted field may contain newlines, so rows are not always one line.
  ReportSteps[T](
    header: proc(shown: int): string {.noSideEffect, raises: [].} = "index,value",
    keep: proc(item: T): bool {.noSideEffect, raises: [].} = true,
    row: proc(item: T; index: int): string {.noSideEffect, raises: [].} = $index & "," & csvField($item),
    footer: proc(shown: int): string {.noSideEffect, raises: [].} = "total," & $shown)
