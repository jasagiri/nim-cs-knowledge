import std/unittest
import propcheck
import nimcs/patterns/abstract_factory

func states(): Gen[CheckState] {.raises: [ValueError].} =
  pick([csUnchecked, csChecked])

func themes(): Gen[Theme] {.raises: [ValueError].} =
  pick([themeLight, themeDark])

# SPEC: GOF-ABSTRACTFACTORY-01
test "GOF-ABSTRACTFACTORY-01 Given any theme, label and state, when products are made, then each carries the kit's family":
  let outcome = check(pair(themes(), pair(stringOf("abc ", 0, 6), states())),
    proc(p: (Theme, (string, CheckState))): bool {.raises: [CatchableError].} =
      let kit = kitFor(p[0])
      let b = kit.button(p[1][0])
      let c = kit.checkbox(p[1][0], p[1][1])
      b.family == kit.family and c.family == kit.family and
        b.kind == wkButton and c.kind == wkCheckbox)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-ABSTRACTFACTORY-02
test "GOF-ABSTRACTFACTORY-02 Given any theme, when the client builds a form from the kit, then all widgets are of that family":
  let outcome = check(pair(themes(), pair(stringOf("abc", 0, 5), states())),
    proc(p: (Theme, (string, CheckState))): bool {.raises: [CatchableError].} =
      let kit = kitFor(p[0])
      let form = loginForm(kit, p[1][0], p[1][1])
      form.len == 2 and form[0].family == kit.family and form[1].family == kit.family)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-ABSTRACTFACTORY-03
test "GOF-ABSTRACTFACTORY-03 Given two themes, when the same form is rendered, then outputs differ and each is stable":
  let outcome = check(pair(stringOf("abc", 0, 5), states()),
    proc(p: (string, CheckState)): bool {.raises: [CatchableError].} =
      func render(t: Theme): seq[string] {.raises: [].} =
        for w in loginForm(kitFor(t), p[0], p[1]):
          result.add(renderWidget(w))
      render(themeLight) != render(themeDark) and
        render(themeLight) == render(themeLight) and
        render(themeDark) == render(themeDark))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-ABSTRACTFACTORY-03
test "GOF-ABSTRACTFACTORY-03 Given a checked box in the dark theme, when rendered, then the text is the known string":
  let w = kitFor(themeDark).checkbox("x", csChecked)
  check renderWidget(w) == "dark:[x] x"
