# Parser combinators

## Intent
A parser is a function: given the input and a position it returns a value and the next position, or an error saying where and what was expected. Small parsers (a character, a digit) are combined into bigger ones by functions (`thenP`, `orElse`, `many`, `chainl1`, `between`), so the grammar in code reads like the grammar on paper.

## Use when / avoid when
- Use for small formats and expression languages where a generator is too heavy.
- Use when parse errors must be values with positions, not exceptions.
- Avoid for large or ambiguous grammars and for performance-critical parsing of big inputs; use a generator or a hand-written scanner.
- Alternatives are tried left to right and the first success wins; if you need real backtracking, structure the grammar so the choice is decidable by the first token.

## Nim shape
`src/nimcs/patterns/parser_combinator.nim`. `Parser[T]` is `proc(input, pos): Result[Parsed[T], ParseError]` with `noSideEffect, raises: []`. Combinators are generic `func`s returning closures. Recursion goes through `lazyP`. The module defines an arithmetic grammar (`+ - *`, parentheses, left-associative) producing an immutable `Expr` tree, with `parseArithmetic`, `print`, `printSpaced` and `evaluate`.

```nim
import nimcs/fp/result
import nimcs/patterns/parser_combinator

let r = parseArithmetic("1 + 2 * (3 - 1)")
doAssert r.isOk
doAssert print(r.value) == "(1+(2*(3-1)))"
doAssert evaluate(r.value).value == 5
let bad = parseArithmetic("1 +")
doAssert bad.isErr
doAssert bad.error.pos == 3
```

Building a parser of your own from the combinators:

```nim
import nimcs/fp/result
import nimcs/patterns/parser_combinator

let digits = many1(digit())
let pairP = thenP(digits, thenP(charP(','), digits))
let r = pairP("12,345", 0)
doAssert r.isOk
doAssert r.value.next == 6
doAssert r.value.value[0] == @['1', '2']
doAssert pairP("12;3", 0).error == ParseError(pos: 2, expected: "','")
```

## Laws and invariants
Why this is testable: a parser is a pure function of a string, so a printer can be the oracle (parse after print gives the tree back), host arithmetic can be the oracle for precedence, and arbitrary strings can be thrown at it because failure is a value.
- Round trip: `parseArithmetic(print(e)) == e` for every tree (PAT-PARSERCOMBINATOR-01).
- Precedence and left associativity agree with host arithmetic (PAT-PARSERCOMBINATOR-02).
- Arbitrary text gives a value: an error inside the text, or a tree that reprints and reparses to itself; junk after a valid expression is an error at the junk (PAT-PARSERCOMBINATOR-03).
- `many` never fails and consumes exactly the leading matches; `orElse(p, q)` equals `p` where `p` succeeds (PAT-PARSERCOMBINATOR-04).
- Blanks between tokens do not change the tree (PAT-PARSERCOMBINATOR-05).
- Input over 1024 bytes or nested deeper than 64 parentheses is refused with an error value, not a crash; recursion depth follows nesting and chain length, so the limits are what make "any string" safe (PAT-PARSERCOMBINATOR-07).
- Print, parse and evaluate equals an independent stack model; values beyond 2^31 are an out-of-range error (PAT-PARSERCOMBINATOR-06).

## Complexity
Linear in the input for this grammar: each character is examined a constant number of times, because choices are decided by one token and `many` never re-reads. The recursive-descent depth equals the parenthesis nesting depth. Each call of `exprP()` builds the parser closures again; build once and reuse if parsing in a loop.

## Pitfalls
A rule that builds itself while it is being built never returns.

```nim bad
func exprP(): Parser[Expr] =
  between(charP('('), exprP(), charP(')'))
```

Defer the recursive reference with `lazyP`, which builds the parser only when it runs:

```nim
import nimcs/fp/result
import nimcs/patterns/parser_combinator

doAssert parseArithmetic("((1))").isOk
doAssert parseArithmetic("((1)").isErr
```

The grammar functions themselves recurse once per open parenthesis, and `print`, `evaluate` and `==` recurse once per tree level: a parser for untrusted text needs a limit, and `parseArithmetic` checks `MaxInputLen` and `MaxNesting` before parsing (calling `exprP()` directly has none). When alternatives fail at the same place, `orElse` joins what each expected (`a digit or '('`) instead of reporting only the last one.

Another trap is a `many` over a parser that can succeed without consuming input: without a progress guard it spins forever. `many` here stops when an iteration consumes nothing.

## Related
- `pipeline.md` and `tagless_final.md` (other compositions of small typed pieces)
- `state_machine.md` (rejecting invalid input with a value)
- `interpreter.md` (the GoF view of evaluating a tree)

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `14f064178f32050b` Introduction to Functional Programming (TU Delft OCW)
