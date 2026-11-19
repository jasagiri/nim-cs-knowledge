# Template Method

## Intent
Several variants of a procedure share a fixed sequence of steps and differ in some of them. The OO pattern fixes the order in a base-class method and lets subclasses override the steps. In functional Nim the skeleton is a higher-order `func` that takes the varying steps as values; a "subclass" is a record of procs in which some fields differ. The pattern disappears into function parameters, and a variant cannot break the order because it never writes the skeleton.

## Use when / avoid when
- Use when two or more variants run the same sequence (load, filter, format, summarise) with different step implementations: report formats, import/export pipelines, test fixtures.
- Use a record of steps (`ReportSteps`) when there are several steps and variants override a few: `withFooter` and friends build variants from a default.
- Avoid when only one step varies: pass one function (`strategy`).
- Avoid when variants disagree on the order of steps; then they do not share a skeleton.

## Nim shape
The module is `src/nimcs/patterns/template_method.nim`. `render(items, steps)` is the skeleton: keep the accepted items, then emit the header, one row per kept item, and the footer, joined by newlines. `defaultSteps[T]()` and `csvSteps[T]()` are two variants; `withFooter`, `withKeep` and `withRow` derive new variants by replacing one step.

```nim
import nimcs/patterns/template_method

doAssert render([5, 8], defaultSteps[int]()) == "Report (2 items)\n1. 5\n2. 8\nend"
doAssert render([5, 8], csvSteps[int]()) == "index,value\n0,5\n1,8\ntotal,2"
```

Deriving a variant overrides one step and inherits the rest:

```nim
import nimcs/patterns/template_method

func isOdd(x: int): bool {.raises: [].} = x mod 2 != 0

let odds = defaultSteps[int]().withKeep(isOdd)
doAssert render([1, 2, 3, 4], odds) == "Report (2 items)\n1. 1\n2. 3\nend"
```

## Laws and invariants
- The first line is the header and the last is the footer, whatever the items (GOF-TEMPLATE-01).
- There is one row per kept item, and header and footer receive that count (GOF-TEMPLATE-02).
- Replacing only the footer changes only the last line (GOF-TEMPLATE-03).
- Rendering is deterministic (GOF-TEMPLATE-04).
- The default and CSV variants share the skeleton and give the documented texts, also for no items (GOF-TEMPLATE-05).
- Row indices count kept items from zero (GOF-TEMPLATE-06).
- CSV output is RFC 4180 valid: `csvField` quotes fields with commas, quotes, CR or LF, and a CSV reader recovers every field (GOF-TEMPLATE-07). A quoted field may contain newlines, so a CSV row is not always one line.

## Complexity
O(n) calls to `keep` and `row` plus the cost of the steps; the output is built in one `join`, so it is linear in the output size. Deriving a variant copies the small record of procs.

## Pitfalls
Using an inheritance hierarchy with `method` to override steps, so the skeleton, the steps and the dispatch are tangled and every variant needs a type:

```nim bad
type Report = ref object of RootObj

method header(r: Report): string {.base.} = "Report"
method footer(r: Report): string {.base.} = "end"

proc render(r: Report; rows: seq[string]): string =
  r.header() & "\n" & rows.join("\n") & "\n" & r.footer()   # also needs strutils
```

Fix: a record of procs plus a generic skeleton, as in `render`. Another trap is a step that hides a failure behind a default (for example a `row` that returns "" on bad input); make a step that can fail return `Result` and let the skeleton propagate it. A skeleton that exposes its own intermediate state to the steps (`var` parameters) lets variants reintroduce order dependence; steps here receive values only.

## Related
- `strategy.nim` (one varying step)
- `visitor.nim` (varying operations over a structure)
- `chain_of_responsibility.nim` (steps tried in order until one answers)

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `25f90d554113e6d5` Scala & Design Patterns: Exploring Language Expressivity
- `0789f21330e7f72a` Source Making Design Patterns and UML
- `690b10bb5f31ac02` The Catalog of Design Patterns
