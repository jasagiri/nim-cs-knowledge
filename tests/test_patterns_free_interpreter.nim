import std/[unittest, tables, algorithm, strutils]
import propcheck
import nimcs/patterns/free_interpreter

const keys = ["k0", "k1", "k2"]
const vals = ["v0", "v1", "v2"]

func buildProgram(raw: seq[(int, (int, int))]): Program {.raises: [].} =
  for (op, kv) in raw:
    let k = keys[kv[0]]
    let v = vals[kv[1]]
    case op
    of 0: result.add put(k, v)
    of 1: result.add get(k)
    of 2: result.add del(k)
    else: result.add whenMissing(k, @[put(k, v), put(k, v & "'"), get(k)])

func programs(): Gen[Program] {.raises: [ValueError].} =
  seqOf(pair(intIn(0, 3), pair(intIn(0, 2), intIn(0, 2))), 0, 14).map(buildProgram)

func countInstr(p: Program): int {.raises: [].} =
  for i in p:
    result += 1
    if i.kind == ikWhenMissing: result += countInstr(i.body)

# The second interpreter: it really mutates a table. Everything it knows comes from the program.
proc runShell(p: Program; store: var Table[string, string]; output: var seq[string]) =
  for i in p:
    case i.kind
    of ikPut: store[i.putKey] = i.putValue
    of ikGet: output.add i.key & "=" & store.getOrDefault(i.key, "<missing>")
    of ikDelete: store.del i.key
    of ikWhenMissing:
      if i.missingKey notin store: runShell(i.body, store, output)

func sortedEntries(t: Table[string, string]): seq[Entry] {.raises: [].} =
  for k, v in t: result.add Entry(key: k, value: v)
  result.sort(proc(a, b: Entry): int = cmp(a.key, b.key))

# SPEC: PAT-FREEINTERPRETER-01
test "PAT-FREEINTERPRETER-01 Given two programs, when run in sequence or concatenated, then store and output agree":
  let outcome = check(pair(programs(), programs()), proc(p: (Program, Program)): bool {.raises: [CatchableError].} =
    let whole = runPure(p[0] & p[1])
    let first = runPure(p[0])
    let second = runPure(p[1], first.store)
    whole.store == second.store and whole.output == first.output & second.output)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-FREEINTERPRETER-02
test "PAT-FREEINTERPRETER-02 Given any key and value, when a put is followed by a get, then the get reads what was put":
  let outcome = check(pair(programs(), pair(intIn(0, 2), intIn(0, 2))), proc(p: (Program, (int, int))): bool {.raises: [CatchableError].} =
    let k = keys[p[1][0]]
    let v = vals[p[1][1]]
    let r = runPure(p[0] & @[put(k, v), get(k)])
    r.output[^1] == k & "=" & v)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-FREEINTERPRETER-03
test "PAT-FREEINTERPRETER-03 Given any program and any start, when ensureDefault runs twice, then the store equals running it once":
  let outcome = check(pair(programs(), pair(intIn(0, 2), intIn(0, 2))), proc(p: (Program, (int, int))): bool {.raises: [CatchableError].} =
    let start = runPure(p[0]).store
    let once = ensureDefault(keys[p[1][0]], vals[p[1][1]])
    runPure(once & once, start) == runPure(once, start))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-FREEINTERPRETER-04
test "PAT-FREEINTERPRETER-04 Given any program, when simplified, then the interpreter gives the same store and output":
  let outcome = check(programs(), proc(p: Program): bool {.raises: [CatchableError].} =
    runPure(simplify(p)) == runPure(p))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-FREEINTERPRETER-05
test "PAT-FREEINTERPRETER-05 Given any program, when simplified twice, then nothing more changes and it is never longer":
  let outcome = check(programs(), proc(p: Program): bool {.raises: [CatchableError].} =
    let s = simplify(p)
    simplify(s) == s and countInstr(s) <= countInstr(p))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-FREEINTERPRETER-05
test "PAT-FREEINTERPRETER-05 Given writes to the same key in a row, when simplified, then only the last one stays":
  check simplify(@[put("a", "1"), put("a", "2")]) == @[put("a", "2")]
  check simplify(@[put("a", "1"), del("a")]) == @[del("a")]
  check simplify(@[del("a"), put("a", "1")]) == @[put("a", "1")]
  check simplify(@[put("a", "1"), get("a"), put("a", "2")]).len == 3

# SPEC: PAT-FREEINTERPRETER-06
test "PAT-FREEINTERPRETER-06 Given any program, when run by the pure and by the mutating interpreter, then they agree":
  let outcome = check(programs(), proc(p: Program): bool {.raises: [CatchableError].} =
    let pure = runPure(p)
    var store = initTable[string, string]()
    var output: seq[string]
    runShell(p, store, output)
    output == pure.output and sortedEntries(store) == pure.store)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-FREEINTERPRETER-07
test "PAT-FREEINTERPRETER-07 Given any program, when pretty-printed, then there is one line per instruction and the text is stable":
  let outcome = check(programs(), proc(p: Program): bool {.raises: [CatchableError].} =
    let text = pretty(p)
    let lines = if text.len == 0: 0 else: text.splitLines.len
    lines == countInstr(p) and size(p) == countInstr(p) and pretty(p) == text)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-FREEINTERPRETER-07
test "PAT-FREEINTERPRETER-07 Given a nested program, when pretty-printed, then the body is indented under its guard":
  let p = @[whenMissing("a", @[put("a", "1")]), get("a")]
  check pretty(p) == "when-missing a\n  put a = 1\nget a"
