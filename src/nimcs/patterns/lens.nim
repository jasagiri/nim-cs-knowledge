## Lens: a getter and a setter bundled so that a deep field of an immutable value can be read and replaced.
##
## Updating `company.ceo.address.city` in immutable data means rebuilding three levels by hand.
## A `Lens[S, A]` focuses on an `A` inside an `S`: `view` reads it, `put` returns a new `S` with
## it replaced, and `compose` chains a lens into a lens so deep access is the composition of
## shallow ones. A lens is only trustworthy if it obeys three laws (get-set, set-get, set-set),
## which are properties to test for every lens you write. Use lenses for nested records that are
## updated often; for one field one level down, plain object copy (`fp/immutable_update`) is
## simpler.

type
  Address* = object
    street*, city*: string
    zip*: int

  Person* = object
    name*: string
    age*: int
    address*: Address

  Company* = object
    name*: string
    ceo*: Person

  Lens*[S, A] = object
    getter: proc(s: S): A {.noSideEffect, raises: [].}
    setter: proc(s: S; a: A): S {.noSideEffect, raises: [].}

func lens*[S, A](getter: proc(s: S): A {.noSideEffect, raises: [].};
                 setter: proc(s: S; a: A): S {.noSideEffect, raises: [].}): Lens[S, A] {.raises: [].} =
  ## Bundles a getter and a setter. Nothing checks the laws; test them.
  Lens[S, A](getter: getter, setter: setter)

func view*[S, A](l: Lens[S, A]; s: S): A {.raises: [].} = l.getter(s)

func put*[S, A](l: Lens[S, A]; s: S; a: A): S {.raises: [].} =
  ## A copy of `s` with the focus replaced; `s` is untouched.
  l.setter(s, a)

func over*[S, A](l: Lens[S, A]; s: S; f: proc(a: A): A {.noSideEffect, raises: [].}): S {.raises: [].} =
  ## Replaces the focus by `f` of the focus.
  l.put(s, f(l.view(s)))

func compose*[S, M, A](outer: Lens[S, M]; inner: Lens[M, A]): Lens[S, A] {.raises: [].} =
  ## Focuses first through `outer`, then through `inner`.
  lens(
    proc(s: S): A {.noSideEffect, raises: [].} = inner.view(outer.view(s)),
    proc(s: S; a: A): S {.noSideEffect, raises: [].} = outer.put(s, inner.put(outer.view(s), a)))

# ── lenses for the example records ─────────────────────────────────────────

func companyCeo*(): Lens[Company, Person] {.raises: [].} =
  lens(
    proc(c: Company): Person {.noSideEffect, raises: [].} = c.ceo,
    proc(c: Company; p: Person): Company {.noSideEffect, raises: [].} = Company(name: c.name, ceo: p))

func addressLens*(): Lens[Person, Address] {.raises: [].} =
  lens(
    proc(p: Person): Address {.noSideEffect, raises: [].} = p.address,
    proc(p: Person; a: Address): Person {.noSideEffect, raises: [].} =
      Person(name: p.name, age: p.age, address: a))

func ageLens*(): Lens[Person, int] {.raises: [].} =
  lens(
    proc(p: Person): int {.noSideEffect, raises: [].} = p.age,
    proc(p: Person; a: int): Person {.noSideEffect, raises: [].} =
      Person(name: p.name, age: a, address: p.address))

func cityLens*(): Lens[Address, string] {.raises: [].} =
  lens(
    proc(a: Address): string {.noSideEffect, raises: [].} = a.city,
    proc(a: Address; c: string): Address {.noSideEffect, raises: [].} =
      Address(street: a.street, city: c, zip: a.zip))

func ceoAge*(): Lens[Company, int] {.raises: [].} =
  companyCeo().compose(ageLens())

func ceoCity*(): Lens[Company, string] {.raises: [].} =
  companyCeo().compose(addressLens()).compose(cityLens())
