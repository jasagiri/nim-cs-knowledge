## Free interpreter: a program is a value, and what it means is decided by whoever runs it.
##
## Instead of calling a key-value store directly, build a `Program`, a list of instruction
## values (`put`, `get`, `delete`, `whenMissing`). Nothing happens while building. Then hand the
## program to an interpreter: `runPure` folds it over an in-memory store, `pretty` prints it,
## a real interpreter could talk to a database. This is dependency injection by interpreter, and
## because the program is data it can also be rewritten (`simplify`) before it runs, which a
## closure cannot be. Use it when you want to test, inspect or optimise the sequence of effects
## without performing them. When programs are fixed and only the backend varies, a record of
## procs (`dependency_record`) is lighter; for new interpreters without a data type see
## `tagless_final`.

import std/[algorithm, options]

type
  InstrKind* = enum
    ikPut, ikGet, ikDelete, ikWhenMissing

  Instr* = object
    case kind*: InstrKind
    of ikPut:
      putKey*, putValue*: string
    of ikGet, ikDelete:
      key*: string
    of ikWhenMissing:
      missingKey*: string
      body*: seq[Instr]   ## runs only when `missingKey` has no value

  Program* = seq[Instr]

  Entry* = object
    key*, value*: string

  Outcome* = object
    ## What the pure interpreter produces: the final store (sorted by key) and the lines `get`
    ## printed, `key=value` or `key=<missing>`.
    store*: seq[Entry]
    output*: seq[string]

func `==`*(a, b: Instr): bool {.raises: [].} =
  if a.kind != b.kind: return false
  case a.kind
  of ikPut: a.putKey == b.putKey and a.putValue == b.putValue
  of ikGet, ikDelete: a.key == b.key
  of ikWhenMissing: a.missingKey == b.missingKey and a.body == b.body

func put*(key, value: string): Instr {.raises: [].} =
  Instr(kind: ikPut, putKey: key, putValue: value)

func get*(key: string): Instr {.raises: [].} = Instr(kind: ikGet, key: key)

func del*(key: string): Instr {.raises: [].} = Instr(kind: ikDelete, key: key)

func whenMissing*(key: string; body: Program): Instr {.raises: [].} =
  Instr(kind: ikWhenMissing, missingKey: key, body: body)

func ensureDefault*(key, value: string): Program {.raises: [].} =
  ## Sets `key` only if it has no value. Running it twice equals running it once.
  @[whenMissing(key, @[put(key, value)])]

# ── interpreter 1: pure ────────────────────────────────────────────────────

func lookup(store: seq[Entry]; key: string): Option[string] {.raises: [].} =
  for e in store:
    if e.key == key: return some(e.value)
  none(string)

func upsert(store: seq[Entry]; key, value: string): seq[Entry] {.raises: [].} =
  var found = false
  for e in store:
    if e.key == key:
      found = true
      result.add Entry(key: key, value: value)
    else:
      result.add e
  if not found:
    result.add Entry(key: key, value: value)
    result.sort(proc(a, b: Entry): int = cmp(a.key, b.key))

func remove(store: seq[Entry]; key: string): seq[Entry] {.raises: [].} =
  for e in store:
    if e.key != key: result.add e

func exec(state: Outcome; p: openArray[Instr]): Outcome {.raises: [].} =
  result = state
  for i in p:
    case i.kind
    of ikPut:
      result.store = result.store.upsert(i.putKey, i.putValue)
    of ikGet:
      let found = result.store.lookup(i.key)
      result.output.add i.key & "=" & (if found.isSome: found.get else: "<missing>")
    of ikDelete:
      result.store = result.store.remove(i.key)
    of ikWhenMissing:
      if result.store.lookup(i.missingKey).isNone:
        result = exec(result, i.body)

func runPure*(p: Program; start: seq[Entry] = @[]): Outcome {.raises: [].} =
  ## Interprets `p` over `start` (a store as `runPure` itself returns it, sorted by key).
  exec(Outcome(store: start, output: @[]), p)

# ── interpreter 2: printer ─────────────────────────────────────────────────

func prettyLines(p: openArray[Instr]; indent: string): seq[string] {.raises: [].} =
  for i in p:
    case i.kind
    of ikPut: result.add indent & "put " & i.putKey & " = " & i.putValue
    of ikGet: result.add indent & "get " & i.key
    of ikDelete: result.add indent & "delete " & i.key
    of ikWhenMissing:
      result.add indent & "when-missing " & i.missingKey
      result.add prettyLines(i.body, indent & "  ")

func pretty*(p: Program): string {.raises: [].} =
  ## One line per instruction, bodies indented by two spaces; an empty program prints as "".
  let lines = prettyLines(p, "")
  for n, line in lines:
    if n > 0: result.add "\n"
    result.add line

func `$`*(i: Instr): string {.raises: [].} =
  ## The instruction as `pretty` prints it.
  pretty(@[i])

func size*(p: Program): int {.raises: [].} =
  ## Number of instructions, bodies included.
  for i in p:
    result += 1
    if i.kind == ikWhenMissing: result += size(i.body)

# ── a program-to-program rewrite ───────────────────────────────────────────

func isWrite(i: Instr): bool {.raises: [].} = i.kind in {ikPut, ikDelete}

func writtenKey(i: Instr): string {.raises: [].} =
  if i.kind == ikPut: i.putKey else: i.key

func simplify*(p: Program): Program {.raises: [].} =
  ## Drops a `put` or `delete` that the next instruction overwrites with another `put` or
  ## `delete` of the same key (nothing could read it in between), inside bodies too. The result
  ## runs to the same store and output (PAT-FREEINTERPRETER-04) and simplifying again changes
  ## nothing.
  for instr in p:
    var cur = instr
    if cur.kind == ikWhenMissing:
      cur = whenMissing(cur.missingKey, simplify(cur.body))
    if isWrite(cur):
      while result.len > 0 and isWrite(result[^1]) and writtenKey(result[^1]) == writtenKey(cur):
        result.delete(result.high)
    result.add cur
