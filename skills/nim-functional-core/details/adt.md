# Algebraic data types

## Intent
A closed set of shapes is one type with a variant per shape. A function over it is a `case` with one branch for each shape and no catch-all, so adding a shape makes the compiler point at every function that must handle it. Data that is only valid for one shape lives only in that shape's branch, which makes impossible states impossible to write.

## Use when / avoid when
- Use for expression trees, commands, events, protocol messages, tokens: anything with a fixed list of cases.
- Use an enum when the cases carry no data.
- Avoid class hierarchies with `method`: new operations then touch every class, and the compiler cannot check exhaustiveness.
- Avoid an object variant for an open set that plugins extend; use a table of functions or a `Result`-returning registry instead.

## Nim shape
`src/nimcs/fp/adt.nim`: `Expr` with `num`, `neg`, `add`, `mul`, `divide`. Recursion goes through `ref` to immutable nodes; `eval` returns a `Result` so that division by zero and overflow are values.

```nim
import nimcs/fp/[result, adt]

let e = add(num(2), mul(num(3), num(4)))
doAssert eval(e) == ok(14, EvalError)
doAssert show(e) == "(2 + (3 * 4))"
doAssert show(neg(num(1))) != show(num(-1))   # show is injective on trees

let bad = divide(num(1), add(num(2), neg(num(2))))
doAssert eval(bad) == err(int, divideByZero)
doAssert simplify(add(num(0), num(5))) == num(5)
```

Writing your own `func` over a variant, mention every kind and leave out `else`:

```nim
import nimcs/fp/adt

func depth(e: Expr): int {.raises: [].} =
  case e.kind
  of ekNum: 1
  of ekNeg: 1 + depth(e.operand)
  of ekAdd, ekMul, ekDiv: 1 + max(depth(e.left), depth(e.right))

doAssert depth(add(num(1), neg(num(2)))) == 3
```

## Laws and invariants
- `eval` gives the arithmetic value of each shape (FP-ADT-01).
- Division by zero and overflow are `EvalError` values; the left operand's error comes first (FP-ADT-02).
- `eval(simplify(e)) == eval(e)`, including at `low(int)` and `high(int)` (FP-ADT-03). `--x` is therefore not rewritten to `x` unless `x` is a number: `-low(int)` overflows, so dropping the pair could turn an error into a value.
- `simplify` is idempotent and removes `0 + x`, `x + 0`, `1 * x`, `x * 1`, `x / 1` and folds constants (FP-ADT-04); it never grows the tree (FP-ADT-05).
- `show` is fully parenthesised, prints a negation as `neg(...)`, and two trees print the same exactly when they are equal (FP-ADT-06); `size` counts nodes.
- `==` on `Expr` is structural (FP-ADT-07).

## Complexity
`eval`, `size`, `show` and `simplify` are O(n) in the number of nodes; recursion depth equals tree depth, so a degenerate tree of a million nodes can exhaust the stack. `simplify` allocates a new tree. `==` is O(n).

## Pitfalls
An `else` branch on an enum hides new shapes: the compiler is silent when a case is added.

```nim bad
func isLeaf(e: Expr): bool =
  case e.kind
  of ekNum: true
  else: false          # a new leaf kind added later would be called "not a leaf"
```

```nim
import nimcs/fp/adt

func isLeaf(e: Expr): bool {.raises: [].} =
  case e.kind
  of ekNum: true
  of ekNeg, ekAdd, ekMul, ekDiv: false

doAssert isLeaf(num(1)) and not isLeaf(neg(num(1)))
```

Also remember that `==` on a bare `ref object` compares addresses; define a structural `==` as `adt.nim` does.

## Related
`result.md`, `smart_constructor.md`, `monoid.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `e99282b528704855` A Scala Tutorial for Java programmers
- `21a878bd1e78232f` A Tour of Scala - an interactive scala tutorial
- `d211930924723e5e` Anatomy of Programming Languages
- `c59d2a0bec136dcc` Effective Scala
- `04bc6d730024731d` Haskell Notes for Professionals
- `6a3d106c56e40887` OCaml From the Ground Up
- `04c90d5ac6a2d0db` Real World OCaml
- `4983fd2e157f75bc` Scala Tutorial
