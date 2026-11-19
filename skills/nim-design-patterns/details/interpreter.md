# Interpreter

## Intent
Evaluate sentences of a small language. The OO pattern gives every grammar rule a class with an `interpret(context)` method. In functional Nim the grammar is one object variant (an algebraic data type) and each interpretation is a function with an exhaustive `case`: a fold over the tree. Evaluating, printing, size and optimisation are separate functions over the same type, and none edits it.

## Use when / avoid when
- Use for small domain languages: formulas, filters, access rules, query conditions, configuration expressions.
- Use when you want several interpretations of the same tree (evaluate, print, simplify, type-check).
- Avoid when the language has real syntax, scoping and modules: write a parser and a compiler pipeline; keep this shape only for the tree it produces.
- Avoid when the operations are fixed and the node types grow without bound; a record of procs (`visitor.nim`) is the open form.

## Nim shape
The module is `src/nimcs/patterns/interpreter.nim`. `Expr` is a `ref` object variant with private fields: nodes are made by `num`, `variable` (a smart constructor returning a `Result`, refusing non-identifier names), `neg`, `add`, `mul`, `divide`, and read through the accessors `kind`, `num`, `name`, `operand`, `left`, `right`, so an invalid node cannot be written by naming fields (recursion needs the indirection; nodes are immutable by convention) with numbers, variables, negation, add, multiply and divide. `eval(e, env)` returns `Result[int, EvalError]`; arithmetic is checked against `Limit`, so nothing overflows and division by zero is a value. `fold` does constant folding and keeps a failing subtree so errors survive optimisation.

```nim
import nimcs/fp/result
import nimcs/patterns/interpreter

let x = variable("x").value        # smart constructor: only identifiers are accepted
let e = add(mul(num(2), num(3)), x)
doAssert eval(e, [("x", 4)]).value == 10
doAssert show(e) == "((2 * 3) + x)"
doAssert show(fold(e)) == "(6 + x)"
doAssert eval(variable("y").value, [("x", 4)]).error == evUnbound
doAssert variable("a + b").error == veBadName
```

Adding an interpretation is adding a function; the compiler checks it covers every node kind:

```nim
import nimcs/patterns/interpreter

func depth(e: Expr): int {.raises: [].} =
  case e.kind
  of ekNum, ekVar: 1
  of ekNeg: 1 + depth(e.operand)
  of ekAdd, ekMul, ekDiv: 1 + max(depth(e.left), depth(e.right))

doAssert depth(add(num(1), neg(num(2)))) == 3
```

## Laws and invariants
- `eval` computes the arithmetic value (GOF-INTERP-01) and reports the first failure in reading order (GOF-INTERP-02).
- `eval(fold(e)) == eval(e)`, errors included, also for literals beyond `Limit` or at `low(int)`/`high(int)`: both go through `combine`, which range-checks its operands (GOF-INTERP-03).
- `fold(fold(e))` equals `fold(e)` (GOF-INTERP-04); `fold` never grows the tree (GOF-INTERP-05).
- A closed expression that evaluates folds to its value (GOF-INTERP-06); a failing constant subtree is kept (GOF-INTERP-07).
- `show` is fully parenthesised and injective: equal texts mean structurally equal trees (GOF-INTERP-08). That holds because `variable` is a smart constructor that accepts only identifiers (GOF-INTERP-09), and the private fields make the constructors the only way to build a node (checked with `compiles`); a name like `"a + b"` is refused instead of being able to imitate an operator.

## Complexity
`eval`, `fold`, `show` and `size` are O(n) in the number of nodes; recursion depth equals tree depth, so a very deep tree can exhaust the stack (build deep trees iteratively or evaluate with an explicit stack). Variable lookup in `env` is linear in the bindings; use a table or sorted seq for large environments.

## Pitfalls
Using `else` on the node kind, or a catch-all that returns a default, so a new node kind is evaluated as 0 without any compiler complaint:

```nim bad
func eval(e: Expr): int =
  case e.kind
  of ekNum: e.num
  of ekAdd: eval(e.left) + eval(e.right)
  else: 0
```

Fix: list every kind (the compiler then rejects a missing one). Also do not let arithmetic overflow or divide by zero raise: make both values in the result type, as `eval` does, and make the optimiser (`fold`) call the same `combine` so the two can never disagree on a corner case.

## Related
- `visitor.nim` (the same idea for shapes, plus the record-of-procs form)
- `state.nim` (event interpretation as a transition function)
- `../../nim-functional-core` (`Result` and folds)

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `57d435a932247e45` Crafting Interpreters
- `25f90d554113e6d5` Scala & Design Patterns: Exploring Language Expressivity
- `5b1535e53ceaa7c4` SICP Distilled - An idiosyncratic tour of SICP in Clojure
- `0789f21330e7f72a` Source Making Design Patterns and UML
