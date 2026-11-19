# Abstract Factory

## Intent
A client needs several products that must belong together (all widgets of one theme) and must not
name their concrete shape. The OO pattern is an interface with one `createX()` per product. In
Nim, the family is a plain object whose fields are proc values; choosing the family is choosing
one value of that object.

## Use when / avoid when
- Use when two or more products must stay mutually consistent and the family is picked once
  (theme, platform, vendor).
- Use a single proc value (`factory_method.md`) when there is only one product.
- Avoid when products do not constrain each other: just pass them separately.
- Avoid growing the kit casually: adding a product means touching every family. If the set of
  products is open, use a `Table` of named procs instead.

## Nim shape
`WidgetKit` is the abstract factory; `kitFor` is the only place that knows which concrete products
belong to which theme. Client code (`loginForm`) receives a kit and never sees a `Theme`.

Module: `src/nimcs/patterns/abstract_factory.nim`.

```nim
import nimcs/patterns/abstract_factory

let dark = kitFor(themeDark)
let form = loginForm(dark, "ana", csChecked)
doAssert form[0].family == "dark" and form[1].family == "dark"
doAssert renderWidget(form[1]) == "dark:[sign in]"
doAssert renderWidget(loginForm(kitFor(themeLight), "ana", csUnchecked)[0]) == "light:[ ] remember ana"
```

## Laws and invariants
- Every product of `kitFor(t)` carries `t`'s family, whatever label and state it gets
  (GOF-ABSTRACTFACTORY-01).
- A client given a kit returns only widgets of that kit's family (GOF-ABSTRACTFACTORY-02).
- Two different themes render the same input differently; each theme renders it identically every
  time, so there is no hidden state in a kit (GOF-ABSTRACTFACTORY-03).

## Complexity
Constructing a kit allocates its closures once; each product call is an indirect call. Keep the kit
in a `let` and reuse it.

## Pitfalls
Letting the client branch on the theme defeats the pattern: a new theme then edits every client.

```nim bad
import nimcs/patterns/abstract_factory

func loginButton(t: Theme): string =
  if t == themeDark: "dark:[go]" else: "light:[go]"
```

Ask the kit instead:

```nim
import nimcs/patterns/abstract_factory

func loginButton(kit: WidgetKit): string =
  renderWidget(kit.button("go"))

doAssert loginButton(kitFor(themeDark)) == "dark:[go]"
```

## Related
- `factory_method.md`, `builder.md`, `bridge.md` (the same record-of-procs shape for a different purpose).

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `25f90d554113e6d5` Scala & Design Patterns: Exploring Language Expressivity
- `0789f21330e7f72a` Source Making Design Patterns and UML
- `690b10bb5f31ac02` The Catalog of Design Patterns
