# Free interpreter (program as data)

## Intent
Describe a computation as a value instead of performing it. A `Program` is a list of instruction values (`put`, `get`, `delete`, `whenMissing`); building one does nothing. A separate interpreter gives it meaning: a pure one folds it over an in-memory store, a printer renders it, a real one would talk to a database. Choosing the interpreter is dependency injection, and because the program is data it can also be rewritten before it runs.

## Use when / avoid when
- Use when you want to test, print, count or optimise a sequence of effects without performing them.
- Use when several backends must run the same program and agree (a fake and a real one).
- Avoid when the program never needs inspecting; a record of procs (`dependency_record.md`) is lighter.
- Avoid when the set of operations changes often and you do not need to look inside programs; `tagless_final.md` avoids the instruction type.

## Nim shape
`src/nimcs/patterns/free_interpreter.nim`. `Instr` is an object variant, `Program` is `seq[Instr]`. `whenMissing(key, body)` nests a body, so programs are trees. Interpreters: `runPure(program, start)` returns an `Outcome` (final sorted store and the lines `get` produced), `pretty` prints. `simplify` is a program-to-program rewrite: it drops a write that the next instruction overwrites.

```nim
import nimcs/patterns/free_interpreter

let p = @[put("a", "1"), put("a", "2"), get("a"),
          whenMissing("b", @[put("b", "x")]), get("b")]
doAssert simplify(p).len == 4
let r = runPure(simplify(p))
doAssert r.output == @["a=2", "b=x"]
doAssert r.store == @[Entry(key: "a", value: "2"), Entry(key: "b", value: "x")]
doAssert pretty(@[get("a")]) == "get a"
```

## Laws and invariants
Why this is testable: the program is an ordinary value, so a generator can build random programs and the pure interpreter can be compared with any other interpreter or with a rewritten program.
- Running a concatenation equals running the parts in sequence, threading the store (PAT-FREEINTERPRETER-01).
- A `get` right after a `put` reads what was put (PAT-FREEINTERPRETER-02).
- `ensureDefault` run twice equals run once, from any start store (PAT-FREEINTERPRETER-03).
- `simplify` preserves the interpreter's store and output (PAT-FREEINTERPRETER-04).
- `simplify` is idempotent and never longer; a write separated by a read is kept (PAT-FREEINTERPRETER-05).
- An interpreter that mutates a real table agrees with the pure one on any program (PAT-FREEINTERPRETER-06).
- `pretty` prints one line per instruction, indented by nesting, the same text every time (PAT-FREEINTERPRETER-07).

## Complexity
`runPure` is O(n * s) for n executed instructions and s keys (the store is a sorted list; a persistent map gives O(n log s)). `pretty` and `size` are O(n). `simplify` is O(n) with an output stack.

## Pitfalls
An instruction that is a closure is opaque: it cannot be printed, compared, simplified or run by a second interpreter.

```nim bad
import std/tables
type Instr = proc(store: var Table[string, string])
```

Make the instruction a variant whose fields say what it does, as `Instr` here does. Equality of variants has to be written by hand, because the generated `==` does not work for `case` objects:

```nim
import nimcs/patterns/free_interpreter

doAssert put("a", "1") == put("a", "1")
doAssert put("a", "1") != get("a")
doAssert whenMissing("k", @[get("k")]) == whenMissing("k", @[get("k")])
```

Also state the rewrite's contract (same store, same output) and test it with random programs; a rewrite that is only checked on examples will eventually reorder a read past a write.

## Related
- `tagless_final.md` (the same idea without an instruction type)
- `dependency_record.md`
- `functional_core.md` (effects as data, one step at a time)
- `interpreter.md` (the GoF pattern in this repository)

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `04bc6d730024731d` Haskell Notes for Professionals
- `90944eadae97da9a` Learning Scalaz
