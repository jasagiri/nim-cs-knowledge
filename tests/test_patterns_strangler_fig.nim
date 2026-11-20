import std/[unittest, strutils]
import propcheck
import nimcs/patterns/strangler_fig

func legacy(request: string): string {.raises: [].} = "L:" & request

func modern(request: string): string {.raises: [].} =
  ## Agrees with the legacy system except on requests that contain a 'z'.
  if 'z' in request: "M:" & request else: "L:" & request

func prefixes(): seq[string] {.raises: [].} = @["/", "/a", "/ab", "/b", "/a/b", "a"]

func tableOf(rows: seq[(int, bool)]; fallbackModern: bool): Table {.raises: [].} =
  ## Builds a table from indexes into `prefixes`; an index out of range is skipped.
  result = initTable().withFallback(if fallbackModern: tgModern else: tgLegacy)
  for (i, isModern) in rows:
    if i in 0 ..< prefixes().len:
      let t = withRoute(result, prefixes()[i], if isModern: tgModern else: tgLegacy)
      doAssert t.isOk
      result = t.value

func rowsGen(): Gen[seq[(int, bool)]] {.raises: [ValueError].} = seqOf(pair(intIn(0, 5), boolean()), 0, 7)

func requestGen(): Gen[string] {.raises: [ValueError].} = stringOf("ab/z", 0, 6)

# SPEC: PAT-STRANGLERFIG-01
test "PAT-STRANGLERFIG-01 Given a table and a request, when routed, then the longest named prefix of the request decides and the fallback applies when there is none":
  let outcome = check(pair(pair(rowsGen(), boolean()), requestGen()),
      proc(x: ((seq[(int, bool)], bool), string)): bool {.raises: [CatchableError].} =
    let ((rows, fb), request) = x
    let t = tableOf(rows, fb)
    var expected = t.fallback
    for k in countdown(request.len, 1):
      var named = false
      for e in t.entries:
        if e.prefix == request[0 ..< k]:
          expected = e.target
          named = true
          break
      if named: break
    t.route(request) == expected)
  checkpoint describe(outcome)
  check outcome.passed
  let t = tableOf(@[(1, true), (2, false)], false)   # "/a" modern, "/ab" legacy
  check t.route("/abc") == tgLegacy
  check t.route("/ax") == tgModern
  check t.route("/q") == tgLegacy

# SPEC: PAT-STRANGLERFIG-02
test "PAT-STRANGLERFIG-02 Given systems that agree on a request, when a prefix is strangled, then the response is unchanged, and requests outside the prefix keep their route":
  let outcome = check(pair(pair(rowsGen(), boolean()), pair(intIn(0, 5), requestGen())),
      proc(x: ((seq[(int, bool)], bool), (int, string))): bool {.raises: [CatchableError].} =
    let ((rows, fb), (pi, request)) = x
    let t = tableOf(rows, fb)
    let p = prefixes()[pi]
    let moved = t.strangle(p)
    if moved.isErr: return false
    if not request.startsWith(p) and moved.value.route(request) != t.route(request): return false
    if 'z' notin request and moved.value.serve(legacy, modern, request) != t.serve(legacy, modern, request):
      return false
    true)
  checkpoint describe(outcome)
  check outcome.passed
  # The test can see a difference: the systems disagree on 'z', so moving "/a" changes that answer.
  let t = initTable()
  check t.serve(legacy, modern, "/az") == "L:/az"
  check t.strangle("/a").value.serve(legacy, modern, "/az") == "M:/az"

# SPEC: PAT-STRANGLERFIG-03
test "PAT-STRANGLERFIG-03 Given a table, when a prefix is named twice, then the last target wins, and a retreat undoes a strangle of a legacy prefix":
  let outcome = check(pair(pair(rowsGen(), boolean()), pair(intIn(0, 5), requestGen())),
      proc(x: ((seq[(int, bool)], bool), (int, string))): bool {.raises: [CatchableError].} =
    let ((rows, fb), (pi, request)) = x
    let t = tableOf(rows, fb)
    let p = prefixes()[pi]
    let once = t.withRoute(p, tgModern).value
    if once.withRoute(p, tgModern).value != once: return false
    if once.withRoute(p, tgLegacy).value != t.withRoute(p, tgLegacy).value: return false
    if t.route(p) == tgLegacy:
      let back = t.strangle(p).value.retreat(p).value
      if back.route(request) != t.route(request): return false
    true)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-STRANGLERFIG-04
test "PAT-STRANGLERFIG-04 Given a table, when asked if it is retired, then it is exactly when the fallback and every entry name the modern system":
  let outcome = check(pair(rowsGen(), pair(boolean(), requestGen())),
      proc(x: (seq[(int, bool)], (bool, string))): bool {.raises: [CatchableError].} =
    let (rows, (fb, request)) = x
    let t = tableOf(rows, fb)
    # the model: the last write for each prefix wins; an index out of range names nothing
    var last: array[6, bool]
    var named: array[6, bool]
    for (i, isModern) in rows:
      if i in 0 ..< prefixes().len:
        last[i] = isModern
        named[i] = true
    var allModern = fb
    for i in 0 ..< prefixes().len:
      if named[i] and not last[i]: allModern = false
    if t.isRetired != allModern: return false
    (not t.isRetired) or t.route(request) == tgModern)
  checkpoint describe(outcome)
  check outcome.passed
  check not initTable().isRetired
  check initTable().withFallback(tgModern).isRetired

# SPEC: PAT-STRANGLERFIG-05
test "PAT-STRANGLERFIG-05 Given an empty prefix, when named, then it is refused":
  check initTable().withRoute("", tgModern).error == teEmptyPrefix
  check initTable().strangle("").isErr
