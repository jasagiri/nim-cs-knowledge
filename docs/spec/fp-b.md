# Specification: functional foundations (FP), part b

Each row is a law or an externally visible behaviour; each ID has at least one test tagged `# SPEC: <ID>` in `tests/test_fp_<concept>.nim` (rows for sections added to existing pages are in `tests/test_fp_<concept>_more.nim`).

| ID | Concept | Statement |
|---|---|---|
| FP-FUNCTORMONAD-01 | functor_monad | Functor laws hold for `Option`, `Result`, `seq` and `Stream`: `x.map(identity) == x` and `x.map(f).map(g) == x.map(compose(g, f))`. |
| FP-FUNCTORMONAD-02 | functor_monad | Applicative identity: applying a wrapped `identity` to an `Option` or `Result` gives the value back. |
| FP-FUNCTORMONAD-03 | functor_monad | Applicative homomorphism and interchange: `some(f).ap(some(x)) == some(f(x))` (also for `Result`), and `u.ap(some(y)) == some(g => g(y)).ap(u)`. |
| FP-FUNCTORMONAD-04 | functor_monad | `ap(some(f), x)` equals `x.flatMap(v => some(f(v)))` for `Option` and `Result`. |
| FP-FUNCTORMONAD-05 | functor_monad | Monad laws for `Option`: left identity, right identity, associativity of `flatMap`. |
| FP-FUNCTORMONAD-06 | functor_monad | Monad laws for `seq` with `flatMap` and the singleton list; `flatMap` concatenates in order. |
| FP-FUNCTORMONAD-07 | functor_monad | `none` wins in `Option` `ap` and `map2`; in `Result` the first error from the left wins and later errors are not collected. |
| FP-FUNCTORMONAD-08 | functor_monad | `map2(a, b, f)` equals `a.map(curried f).ap(b)`. |
| FP-FUNCTORMONAD-09 | functor_monad | `ap` on lists of functions and values applies every pair, functions outermost; the length is the product. |
| FP-FUNCTORMONAD-10 | functor_monad | A generic that calls `map` on its type parameter is instantiated per type and rejects a type without `map`; a type parameter that takes type arguments (`F[A]`) does not compile. |
| FP-TYPECLASS-01 | type_class | `maxOf` and `minOf` of an `Orderable` sequence are the last and first elements of its sorted copy, and `none` for an empty input. |
| FP-TYPECLASS-02 | type_class | `insertSorted` returns a sorted sequence one element longer with the same elements, and leaves its input unchanged. |
| FP-TYPECLASS-03 | type_class | `isSorted(xs)` holds exactly when `xs` equals its sorted copy. |
| FP-TYPECLASS-04 | type_class | `isTotalOrderOn` holds on generated triples for the instances `int`, `string`, an object type and a `distinct` type with borrowed operators. |
| FP-TYPECLASS-05 | type_class | `isTotalOrderOn` is false for instances that satisfy `Orderable` but break the laws (`<` ignoring part of the value, `float` with `NaN`). |
| FP-TYPECLASS-06 | type_class | A type satisfies `Orderable` exactly when it has `<` and `==`; calling a constrained routine with another type does not compile. |
| FP-TYPECLASS-07 | type_class | `backwards` commutes with `map` and is its own inverse. |
| FP-EQUATIONALREASONING-01 | equational_reasoning | `stagedTotal(xs) == fusedTotal(xs)` for every list of integers. |
| FP-EQUATIONALREASONING-02 | equational_reasoning | `normalizeStaged(s) == normalizeOnce(s)` and `normalizeOnce` is idempotent. |
| FP-EQUATIONALREASONING-03 | equational_reasoning | `rangeSumLoop(n) == rangeSumFormula(n)` while the sum fits in `int`. |
| FP-EQUATIONALREASONING-04 | equational_reasoning | `countIfChunked(xs, p, k) == countIf(xs, p)` for every chunk size `k`, and `countIf` of a concatenation is the sum of the counts. |
| FP-EQUATIONALREASONING-05 | equational_reasoning | For a pure function, binding a call to a name or repeating it gives equal results; with an effect it does not. |
| FP-EQUATIONALREASONING-06 | equational_reasoning | Float sums reassociated (`sumLeft` against `sumRight`) can differ. |
| FP-TAILRECURSION-01 | tail_recursion | `sumToNaive`, `sumToAcc(n, 0)` and `sumToLoop` agree with each other and with `n * (n + 1) / 2`. |
| FP-TAILRECURSION-02 | tail_recursion | `sumToAcc(n, a) == a + sumToNaive(n)`. |
| FP-TAILRECURSION-03 | tail_recursion | `fibNaive`, `fibAcc(n, 0, 1)` and `fibLoop` agree. |
| FP-TAILRECURSION-04 | tail_recursion | `fibLoop` and `fibAcc` reach `fib(92)` without overflow, and `fibLoop` obeys `fib(n) = fib(n - 1) + fib(n - 2)`. |
| FP-TAILRECURSION-05 | tail_recursion | `sumToLoop` runs for `n = 10^8` in constant stack and equals the closed form. |
| FP-TAILRECURSION-06 | tail_recursion | `gcdRec` and `gcdLoop` agree, are symmetric, and the result divides both arguments. |
| FP-TAILRECURSION-07 | tail_recursion | An `if` expression with a subrange-typed branch raises `RangeDefect` when the other branch is out of range, unless that branch is converted. |
| FP-PHANTOMTYPE-01 | phantom_type | `Id[T]` compares and unwraps as its `int`; ids of different kinds do not compile together. |
| FP-PHANTOMTYPE-02 | phantom_type | `Quantity[U]` addition is commutative and associative with `qty(0)` as identity, `-` inverts `+`, `scaled` distributes over `+`; two units, `*`, and `+` with a plain `int` do not compile. |
| FP-PHANTOMTYPE-03 | phantom_type | `toMetersExact(toCentimeters(m)) == ok(m)`, and centimeters that are not a multiple of 100 give an error. |
| FP-PHANTOMTYPE-04 | phantom_type | `validateEmail` accepts exactly the texts with one `@`, a non-empty name and a domain with an inner dot, keeps the text, and `domainOf` is the part after `@`. |
| FP-PHANTOMTYPE-05 | phantom_type | `domainOf` does not compile for a raw address. |
| FP-PHANTOMTYPE-06 | phantom_type | The phantom parameter adds no run-time size: sizes equal those of `int` and `string`. |
| FP-PHANTOMTYPE-07 | phantom_type | An explicit conversion to `Email[Validated]` compiles: the guard stops accidents, not forgery. |
| FP-COMPOSE-07 | compose | A composition keeps the function values it was built from when the variable that held one is reassigned. |
| FP-COMPOSE-08 | compose | A closure reads a captured `var` when called; a `let` copy freezes the value. |
| FP-COMPOSE-09 | compose | Closures made in a `for` loop share the loop variable; closures each built by a function call do not. |
| FP-COMPOSE-10 | compose | `collect` with a filter and a map equals `filter` then `map`, and can build a `HashSet`. |
| FP-COMPOSE-11 | compose | A function returning a function (partial application) gives the results of the two-argument form and composes with `compose`. |
| FP-ADT-08 | adt | Tuple unpacking (plain, nested, in a `for` loop, and as a swap) binds each name to the matching component. |
| FP-ADT-09 | adt | A nested `case` over a variant answers each shape with exactly one branch. |
| FP-ADT-10 | adt | A `case` over a variant that omits a branch does not compile. |
| FP-LAZYSTREAM-09 | lazy_stream | Building a pipeline evaluates nothing. |
| FP-LAZYSTREAM-10 | lazy_stream | `iterate` applies its step once per element after the first: pulling `n` elements applies it `n - 1` times. |
| FP-LAZYSTREAM-11 | lazy_stream | `take(n)` does not pull the source beyond the `n`-th element. |
| FP-LAZYSTREAM-12 | lazy_stream | `filter` runs the predicate on skipped elements and the first match, and on nothing after that match until another element is asked for. |
