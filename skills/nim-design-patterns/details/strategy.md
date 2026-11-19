# Strategy

## Intent
One step of an algorithm has several interchangeable implementations, and the caller should pick one without the algorithm knowing which. The OO pattern wraps each implementation in a class behind an interface. In functional Nim the strategy is a function value: the "interface" is a proc type, the "classes" are procs or closures, and choosing is passing an argument. The pattern as a structure disappears; only the idea (the varying step is a parameter) remains.

## Use when / avoid when
- Use when a computation has a step that varies by configuration, customer or experiment (discount rules, sort keys, retry delays, formatters).
- Use a proc value when the choice is made at run time (read from config, stored in a table); use a generic parameter when it is fixed at compile time (the call is then resolved statically; whether it is inlined is up to the C compiler, so measure before relying on it).
- Avoid when there is exactly one implementation and no foreseeable second one: call the function directly.
- Avoid when the "strategies" need shared mutable state or lifecycle: that is an object with a resource, not a strategy; see `visitor` (record of procs) or keep the state in an explicit value.
- When the variation is a fixed order of steps with several parts replaced, see `template_method`.

## Nim shape
The module is `src/nimcs/patterns/strategy.nim`. A rule is a `PriceRule = proc(price: Cents): Cents {.noSideEffect, raises: [].}`. Constructors such as `percentOff(10)` are `func`s that return closures, and `then` composes two rules, so strategies form a small algebra. The context (`checkout`) takes the rule as an argument and never mentions a concrete rule.

```nim
import nimcs/patterns/strategy

let items = [Cents(1200), Cents(800)]
let tenPercent = percentOff(10)
let cheapestOf = [PriceRule(noDiscount), tenPercent, flatOff(500)]
doAssert checkout(items, tenPercent) == Cents(1800)
doAssert checkout(items, tenPercent.then(flatOff(300))) == Cents(1500)
doAssert cheapest(cheapestOf, Cents(2000)) == Cents(1500)
```

Compile-time selection passes the proc as a generic parameter, so the compiler sees the concrete routine and no closure is needed:

```nim
import nimcs/patterns/strategy

func halve(p: Cents): Cents {.raises: [].} = Cents(value(p) div 2)

doAssert total2([Cents(300), Cents(100)], halve) == Cents(200)
```

## Laws and invariants
- `checkout(items, noDiscount)` is the sum of the items (GOF-STRATEGY-01).
- `percentOff` and `flatOff` return a price between 0 and the input for any argument; out-of-range arguments are clamped (GOF-STRATEGY-02).
- `a.then(b)(x) == b(a(x))` (GOF-STRATEGY-03).
- `cheapest` is at most the price under every rule and at most the unchanged price (GOF-STRATEGY-04).
- A proc value and a generic parameter give the same result (GOF-STRATEGY-05).
- Prices up to `high(int)` never overflow: `percentOff`/`flatOff` stay within `0 .. price` and `checkout` saturates at `high(int)` (GOF-STRATEGY-08).
- `cents(n)` is `none` for negative `n` (GOF-STRATEGY-06); percentages round the discount down (GOF-STRATEGY-07).

## Complexity
Calling a strategy is one indirect call (proc value) or a statically resolved call (generic parameter; inlining is not guaranteed). `checkout` is O(n) in the items; `cheapest` is O(r) in the rules; `then` adds one call per composed rule. A constructor that returns a closure allocates once.

## Pitfalls
Reaching for a class hierarchy with `method`, which brings inheritance, heap allocation and dynamic dispatch for what is one function:

```nim bad
type
  Discount = ref object of RootObj
  TenPercent = ref object of Discount

method apply(d: Discount; price: int): int {.base.} = price
method apply(d: TenPercent; price: int): int = price - price div 10
```

Fix: a proc type and plain procs, as in `PriceRule` above. Two further traps: a strategy that closes over a `var` (it is no longer pure, and the `noSideEffect` proc type rejects it), and a strategy that returns an out-of-range value so every caller must re-check; put the bound in the constructors, as `percentOff` does by clamping.

## Related
- `template_method.nim` (several varying steps under a fixed skeleton)
- `visitor.nim` (a record of procs as the open-world form)
- `chain_of_responsibility.nim` (strategies tried in order)
- `../../nim-functional-core` (function composition, `Option`)

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `25f90d554113e6d5` Scala & Design Patterns: Exploring Language Expressivity
- `0789f21330e7f72a` Source Making Design Patterns and UML
- `690b10bb5f31ac02` The Catalog of Design Patterns
