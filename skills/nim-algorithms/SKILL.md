---
name: nim-algorithms
description: >-
  Choose, write, test or review a classic algorithm in Nim — sorting, binary search, graph
  traversal and shortest paths, minimum spanning trees, dynamic programming, string search,
  number theory, backtracking, greedy and divide and conquer — as a pure `func` over immutable
  input whose correctness laws are property tests. Use whenever a Nim task needs one of these,
  even when the request only names the problem ("find the shortest route", "dedupe and sort",
  "match a pattern in text"). Pairs with nim-functional-core and nim-data-structures.
---

# Algorithms in functional Nim

Every algorithm here has a tested module `src/nimcs/algo/<name>.nim` and a details page. Read the
page before writing that kind of code: it states the laws the code must keep and the mistakes people
make. The house style is ADR-NCK-0002 (skill `nim-functional-core`): public routines are `func` with
`{.raises: [].}`, the input is an `openArray` or an immutable value, the output is a new value, and
working arrays, queues and DP tables are local `var`s nobody outside can see.

Inside this repository, import the module (`import nimcs/<area>/<name>`). In another project the
modules are not a published package: copy the shape from the details page into your own file, or
add this repository's `src/` to the compiler path (`--path:"<repo>/src"`). When the task fixes a
signature the module does not have (`topo(n, deps)` instead of `topoSort(g)`), write the algorithm
in your own file from the page's shape and laws; do not wrap the module behind a converting layer.
Edges are directed (`a -> b`) unless the task says otherwise; for an undirected road add both arcs.

Your own task (a scratch directory, another project): the page's Public API section lists every
exported signature of its module. When the task fixes names, fields or a signature the module does
not have (`Payment(id, cents)` instead of `Command(key, amount)`), write your own types and routines
in your file from the page's shape and laws: the algorithm, the laws, the tests and the example's
layout (its fields and steps) carry over, the type and routine names do not (use the task's names: `circle`, not the example's `square`). Do not convert between your types and the module's on every call;
a thin wrapper that only names the module's operations for the task (an `OrderedMap` over `hamt`, a
`TaskQueue` over `leftist_heap`) is fine. The
spec-row steps in this skill (`docs/spec`, `# SPEC:` lines, `tests/test_<area>_*.nim`) are for adding
a module to this repository; for your own code, put `std/unittest` tests with Given-When-Then names
in `test_<name>.nim` beside it, with no spec file. `propcheck` and `std/unittest` both define
`check`; they take different arguments, so both work in one file. A callback parameter of a
`func` is typed `proc(i: int): bool {.noSideEffect, raises: [].}`: add these pragmas to a fixed
signature that says `proc(i: int): bool`, since a `func` cannot call a callback that may have
effects or raise. Import only what the file uses (an unused import is a compile error under the
strict settings): `Option` needs `std/options`, `Result` needs `nimcs/fp/result`, and a file whose exported
routines return `Result` also writes `export result`, or a test that imports only that file fails
with "undeclared field: 'isErr'". A plain object (no `case`) gets `==` field by field, a sealed one (private fields,
`{.requiresInit.}`) included; an object variant does not. `opt.get` on
`none` is a defect, not an exception, so a `{.raises: [].}` func may call it after `isSome`. When the file
uses `Result`, import it by default: if `import nimcs/fp/result` compiles (a prepared run directory's `nim.cfg` puts `src/` on the path),
use it. Only when it does not, copy this `Result` (the repository's adds `map`, `flatMap` and `==`):

```nim
type Result*[T, E] = object
  case isOk*: bool
  of true: value*: T
  of false: error*: E

func ok*[T, E](v: T; _: typedesc[E]): Result[T, E] {.raises: [].} = Result[T, E](isOk: true, value: v)
func err*[T, E](_: typedesc[T]; e: E): Result[T, E] {.raises: [].} = Result[T, E](isOk: false, error: e)
func isErr*[T, E](r: Result[T, E]): bool {.raises: [].} = not r.isOk

doAssert ok(3, string).value == 3 and err(int, "bad").isErr
```

## How to write one

1. **State the contract as laws first.** A sort: the output is ordered, is a permutation of the
   input, is stable if promised, and `sort(sort(x)) == sort(x)`. A shortest path: no arc can improve
   any distance. Write each as a property test before the body: `import propcheck`, then
   `check(gen, property)` with generators such as `intIn(lo, hi)` and `seqOf(gen, minLen, maxLen)`
   (`import propcheck`: `check(gen, proc(x: T): bool {.raises: [CatchableError].})` returns a result
   with `.passed` and `describe(result)`; generators (each a `Gen[T]`) `intIn(lo, hi)`, `pick(values)`,
   `seqOf(gen, minLen, maxLen)`, `pair(genA, genB)`, `gen.map(f)`; in a test, `checkpoint
   describe(outcome)` then `check outcome.passed`).

A complete property test (propcheck's `check` returns a `CheckResult`; assert its `.passed`). There
are no tuple or graph generators: draw a `seq[int]` and read it as `n` followed by pairs `(a mod n,
b mod n)`. Compare with an oracle: Bellman–Ford for shortest paths, "every arc goes forward" for a
topological order, a reachability search for "a cycle exists".

```nim
import std/[algorithm, unittest]
import propcheck

test "Given any list, when sorted, then no element is greater than the next":
  let outcome = check(seqOf(intIn(-50, 50), 0, 30),
    proc(xs: seq[int]): bool {.raises: [CatchableError].} =
      let s = xs.sorted
      result = true
      for i in 1 ..< s.len:
        if s[i - 1] > s[i]: result = false)
  checkpoint describe(outcome)
  check outcome.passed
```

`Result` comes from `nimcs/fp/result`: `ok(value, ErrorType)`, `err(ValueType, error)`, `isOk`,
`isErr`, `.value`, `.error`, `valueOr`. A module whose exported routines return `Result` writes
`export result`; otherwise its callers must import `nimcs/fp/result` themselves, and `r.isErr` fails
with "undeclared field". The type argument names the other side of the `Result`:

```nim
import nimcs/fp/result

type OrderError = enum oeCycle, oeBadVertex

func firstOf(xs: seq[int]): Result[int, OrderError] {.raises: [].} =
  if xs.len == 0: err(int, oeBadVertex)     # err(ValueType, error)
  else: ok(xs[0], OrderError)               # ok(value, ErrorType)

let r = firstOf(@[])
doAssert r.isErr and r.error == oeBadVertex  # read .error only after isErr
doAssert firstOf(@[4]).value == 4
```
2. **Cross-check against a slower obvious version.** Naive search for KMP / Z / Rabin–Karp,
   brute force over subsets for Kruskal and knapsack, Bellman–Ford for Dijkstra, trial division for
   the sieve. The obvious version is the oracle; the fast one must agree on generated inputs.
3. **Put the failure in the type.** A cycle in a topological sort, a negative cycle in
   Bellman–Ford, an unreachable vertex, a modulus out of range: `Result` or `Option`, never an
   exception or a sentinel like `-1` or `high(int)`. `Option` when "none" is a normal answer with
   one meaning (not found, unreachable); `Result` with an enum when the caller must tell reasons
   apart or the input was wrong (a cycle, a bad vertex). When the signature is fixed and has no error
   channel (`seq[Option[int]]`), state the precondition in the doc comment, keep the routine total
   (an invalid start gives all `none`, a negative `n` an empty result; skip an arc that names a
   vertex outside `0 ..< n`, or one the algorithm cannot take, such as a
   negative weight for Dijkstra; never index out of range; write the edge direction and these skips
   in the doc comment), and add a checked
   companion that returns `Result` and calls it (`fastestChecked(...): Result[seq[Option[int]], E]`).
   A page that says its module refuses an input with an error (Dijkstra's `geNegativeWeight`)
   describes a routine that returns `Result`; with no error channel, skip instead. When the task
   leaves the error type open and the error must carry a value (which vertex), use an object with a
   `kind` enum and the value (a negative `n` or a vertex outside `0 ..< n` is the bad-input kind) (`OrderError = object` with `kind: OrderErrorKind` and `vertex: int`).
4. **Keep mutation local.** In-place partition, heap sift-down, DP table filling and union-find are
   fine inside the routine; the signature stays pure.
5. **Mind the integer range.** Sums and products of `int` can overflow (`OverflowDefect`); either
   take a modulus, return `Option`, or state the caller's precondition in the doc comment.

## Which algorithm

| Need | Use | Page |
|---|---|---|
| sort, small or nearly sorted input | insertion sort | [details/insertion_sort.md](details/insertion_sort.md) |
| sort, stable, predictable O(n log n) | merge sort | [details/merge_sort.md](details/merge_sort.md) |
| sort, many duplicates, functional partition | three-way quick sort | [details/quick_sort.md](details/quick_sort.md) |
| sort in O(1) extra space | heap sort | [details/heap_sort.md](details/heap_sort.md) |
| sort small non-negative integer keys | counting / radix sort | [details/radix_sort.md](details/radix_sort.md) |
| find a boundary in sorted data or a monotone predicate | binary search | [details/binary_search.md](details/binary_search.md) |
| represent a graph as a value | immutable adjacency lists | [details/graph.md](details/graph.md) |
| fewest edges, unweighted | BFS | [details/bfs.md](details/bfs.md) |
| reachability, pre/post order, without recursion depth limits | iterative DFS | [details/dfs.md](details/dfs.md) |
| order tasks by dependencies, detect a cycle | Kahn's topological sort | [details/topo_sort.md](details/topo_sort.md) |
| groups of mutually reachable vertices | strongly connected components | [details/scc.md](details/scc.md) |
| shortest paths, non-negative weights | Dijkstra | [details/dijkstra.md](details/dijkstra.md) |
| shortest paths, negative weights, detect negative cycles | Bellman–Ford | [details/bellman_ford.md](details/bellman_ford.md) |
| all-pairs shortest paths, small dense graphs | Floyd–Warshall | [details/floyd_warshall.md](details/floyd_warshall.md) |
| minimum spanning tree, edge list | Kruskal | [details/kruskal.md](details/kruskal.md) |
| minimum spanning tree, grown from a vertex | Prim | [details/prim.md](details/prim.md) |
| repeated sub-problems | memoization / bottom-up table | [details/memoization.md](details/memoization.md) |
| diff two sequences | longest common subsequence | [details/lcs.md](details/lcs.md) |
| how different two strings are | edit distance | [details/edit_distance.md](details/edit_distance.md) |
| best subset under a weight limit | 0/1 knapsack | [details/knapsack.md](details/knapsack.md) |
| longest increasing run (not contiguous) | LIS in O(n log n) | [details/lis.md](details/lis.md) |
| every occurrence of a pattern | KMP | [details/kmp.md](details/kmp.md) |
| prefix matches at every position | Z-algorithm | [details/z_algorithm.md](details/z_algorithm.md) |
| many patterns, rolling hash | Rabin–Karp | [details/rabin_karp.md](details/rabin_karp.md) |
| sorted suffixes, repeated substrings | suffix array + LCP | [details/suffix_array.md](details/suffix_array.md) |
| gcd, Bezout coefficients, modular power and inverse | number theory | [details/number_theory.md](details/number_theory.md) |
| all primes up to n | sieve of Eratosthenes | [details/sieve.md](details/sieve.md) |
| the n-th Fibonacci number in O(log n) | matrix power | [details/fib_matrix.md](details/fib_matrix.md) |
| enumerate permutations, combinations, n-queens | backtracking as a generator | [details/backtracking.md](details/backtracking.md) |
| local choice provably optimal (interval scheduling, fractional knapsack) | greedy + exchange argument | [details/greedy.md](details/greedy.md) |
| split, solve, combine; recurrences | divide and conquer | [details/divide_conquer.md](details/divide_conquer.md) |

## Shape of a module

```nim
import std/options

func firstTrue*(lo, hi: int; pred: proc(i: int): bool {.noSideEffect, raises: [].}): Option[int] {.raises: [].} =
  ## The smallest i in lo ..< hi with pred(i), assuming pred is monotone (false…false, true…true).
  var a = lo
  var b = hi
  while a < b:
    let mid = a + (b - a) div 2   # not (a + b) div 2: that can overflow
    if pred(mid): b = mid else: a = mid + 1
  if a < hi: some(a) else: none(int)

doAssert firstTrue(0, 10, proc(i: int): bool = i * i >= 20) == some(5)
doAssert firstTrue(0, 3, proc(i: int): bool = false).isNone
```

## Names that clash with the standard library

`nimcs/algo/binary_search` exports `lowerBound`, `upperBound` and `binarySearch`, as
`std/algorithm` does. Import only one of them, or `import std/algorithm except lowerBound, upperBound, binarySearch`.
