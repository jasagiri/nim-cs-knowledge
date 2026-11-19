import std/unittest
import propcheck
import nimcs/patterns/lens

type CompanyRaw = (string, (string, (int, (string, (string, int)))))

func companyOf(p: CompanyRaw): Company {.raises: [].} =
  Company(name: p[0], ceo: Person(name: p[1][0], age: p[1][1][0],
    address: Address(street: p[1][1][1][0], city: p[1][1][1][1][0], zip: p[1][1][1][1][1])))

func companies(): Gen[Company] {.raises: [ValueError].} =
  pair(stringOf("ab", 0, 3), pair(stringOf("cd", 0, 3), pair(intIn(0, 99),
    pair(stringOf("xy", 0, 3), pair(stringOf("mn", 0, 3), intIn(0, 9)))))).map(companyOf)

func texts(): Gen[string] {.raises: [ValueError].} = stringOf("pq", 0, 4)

func getSet[S, A](l: Lens[S, A]; s: S): bool = l.put(s, l.view(s)) == s
func setGet[S, A](l: Lens[S, A]; s: S; a: A): bool = l.view(l.put(s, a)) == a
func setSet[S, A](l: Lens[S, A]; s: S; a, b: A): bool = l.put(l.put(s, a), b) == l.put(s, b)

func plusOne(x: int): int {.raises: [].} = x + 1
func timesTwo(x: int): int {.raises: [].} = x * 2
func same(x: int): int {.raises: [].} = x

# SPEC: PAT-LENS-01
test "PAT-LENS-01 Given any company, when the city is put back as it was read, then nothing changes (get-set)":
  let outcome = check(companies(), proc(c: Company): bool {.raises: [CatchableError].} =
    getSet(ceoCity(), c) and getSet(ceoAge(), c) and getSet(cityLens(), c.ceo.address))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-LENS-02
test "PAT-LENS-02 Given any company and city, when the city is put, then viewing gives that city (set-get)":
  let outcome = check(pair(companies(), texts()), proc(p: (Company, string)): bool {.raises: [CatchableError].} =
    setGet(ceoCity(), p[0], p[1]) and setGet(cityLens(), p[0].ceo.address, p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-LENS-02
test "PAT-LENS-02 Given a lens whose setter clamps its input, when set-get is checked, then a counterexample is found":
  let clampedAge = lens(
    proc(p: Person): int {.noSideEffect, raises: [].} = p.age,
    proc(p: Person; a: int): Person {.noSideEffect, raises: [].} =
      Person(name: p.name, age: max(0, min(120, a)), address: p.address))
  let outcome = check(pair(companies(), intIn(-50, 300)), proc(p: (Company, int)): bool {.raises: [CatchableError].} =
    setGet(clampedAge, p[0].ceo, p[1]))
  check not outcome.passed

# SPEC: PAT-LENS-03
test "PAT-LENS-03 Given any company and two cities, when both are put in turn, then only the last remains (set-set)":
  let outcome = check(pair(companies(), pair(texts(), texts())), proc(p: (Company, (string, string))): bool {.raises: [CatchableError].} =
    setSet(ceoCity(), p[0], p[1][0], p[1][1]) and setSet(addressLens(), p[0].ceo, p[0].ceo.address, p[0].ceo.address))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-LENS-04
test "PAT-LENS-04 Given three lenses, when composed in either grouping, then view and put agree":
  let outcome = check(pair(companies(), texts()), proc(p: (Company, string)): bool {.raises: [CatchableError].} =
    let left = companyCeo().compose(addressLens()).compose(cityLens())
    let right = companyCeo().compose(addressLens().compose(cityLens()))
    left.view(p[0]) == right.view(p[0]) and left.put(p[0], p[1]) == right.put(p[0], p[1]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-LENS-05
test "PAT-LENS-05 Given any company, when over is applied, then it equals put of the function's result and identity changes nothing":
  let outcome = check(companies(), proc(c: Company): bool {.raises: [CatchableError].} =
    let l = ceoAge()
    l.over(c, same) == c and l.over(c, plusOne) == l.put(c, l.view(c) + 1) and
      l.over(l.over(c, plusOne), timesTwo) == l.over(c, proc(x: int): int {.noSideEffect, raises: [].} = timesTwo(plusOne(x))))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-LENS-06
test "PAT-LENS-06 Given any company, when the city is put, then every other field is unchanged and the original is intact":
  let outcome = check(pair(companies(), texts()), proc(p: (Company, string)): bool {.raises: [CatchableError].} =
    let c = p[0]
    let before = c
    let updated = ceoCity().put(c, p[1])
    let expected = Company(name: c.name, ceo: Person(name: c.ceo.name, age: c.ceo.age,
      address: Address(street: c.ceo.address.street, city: p[1], zip: c.ceo.address.zip)))
    updated == expected and c == before)
  checkpoint describe(outcome)
  check outcome.passed
