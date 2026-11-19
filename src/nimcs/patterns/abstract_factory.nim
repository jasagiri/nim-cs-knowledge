## Abstract Factory as a record of constructor procs: one value makes a consistent family.
##
## The OO pattern groups several `createX()` methods in an interface so that a client gets
## products that belong together (all dark, all light). In Nim the family is an object whose
## fields are procs; choosing the family is choosing one value. Use it when several products must
## stay mutually consistent and the client must not name their concrete shape.

type
  Theme* = enum
    themeLight, themeDark

  WidgetKind* = enum
    wkButton, wkCheckbox

  CheckState* = enum
    csUnchecked, csChecked

  Widget* = object
    family*: string
    kind*: WidgetKind
    text*: string

  MakeButton* = proc(label: string): Widget {.noSideEffect, raises: [].}
  MakeCheckbox* = proc(label: string; state: CheckState): Widget {.noSideEffect, raises: [].}

  WidgetKit* = object
    family*: string
    button*: MakeButton
    checkbox*: MakeCheckbox

func familyTag(t: Theme): string {.raises: [].} =
  case t
  of themeLight: "light"
  of themeDark: "dark"

func boxMark(s: CheckState): string {.raises: [].} =
  case s
  of csChecked: "[x] "
  of csUnchecked: "[ ] "

func kitFor*(t: Theme): WidgetKit {.raises: [].} =
  ## The only place that knows which concrete products belong to which theme.
  let fam = familyTag(t)
  WidgetKit(
    family: fam,
    button: proc(label: string): Widget {.noSideEffect, raises: [].} =
      Widget(family: fam, kind: wkButton, text: "[" & label & "]"),
    checkbox: proc(label: string; state: CheckState): Widget {.noSideEffect, raises: [].} =
      Widget(family: fam, kind: wkCheckbox, text: boxMark(state) & label))

func renderWidget*(w: Widget): string {.raises: [].} =
  w.family & ":" & w.text

func loginForm*(kit: WidgetKit; user: string; remember: CheckState): seq[Widget] {.raises: [].} =
  ## Client code: sees only the kit, never a concrete theme.
  @[kit.checkbox("remember " & user, remember), kit.button("sign in")]
