# Object capability

## Intent
Authority only by reference. A capability is a value that names a resource and, by being held, grants the right to use it in specific ways; code that was not handed the value cannot act. There is no ambient authority: no function reaches a file, a global or a clock without being given the capability for it, so a signature shows what a routine may touch. Capabilities are made narrower by attenuation (read-write to read-only, a directory to a subdirectory) and shared by delegation, which is passing the value. An attenuated capability never permits more than the one it came from.

## Use when / avoid when
- Use for code that receives work from, or hands work to, parties you do not fully trust: plugins, request handlers, agents, per-tenant code, actors that exchange references.
- Use instead of a global client or singleton (`singleton.md`): the dependency is an unforgeable value passed in, and it can be narrowed before it is passed on. Use `dependency_record.md` when you only need to swap implementations for testing and every caller may use everything in the record; use a capability when what a caller may do must be limited.
- Use `caretaker.md` when a grant must be revocable and `sealer_unsealer.md` when a value must travel through others without being opened.
- Avoid when everything in the program is equally trusted and nothing needs narrowing: a plain argument is enough.
- Avoid checking an identity or role inside the callee ("is the caller an admin?"): that is ambient authority again. Check nothing; hold the capability or do not.

## Nim shape
The module is `src/nimcs/patterns/object_capability.nim`. `FileCap` is sealed (a private field and `{.requiresInit.}`), so `FileCap(...)` and `var c: FileCap` do not compile outside the module. It holds a set of rights and a path prefix made of whole segments. `rootCap` is the only source of authority; `restrict`, `readOnly` and `narrow` return narrower capabilities (`narrow` returns a `Result`: a bad sub-path is `ceBadPath`). `read` and `write` take the `Store` (a persistent map standing for the resource) and the capability; paths with empty, `.` or `..` segments are refused, and a path outside the prefix is `ceOutside`, so `a` does not cover `ab/x`. Nim cannot hide `rootCap`: the convention is the powerbox, one call at the program's edge, and a text search for `rootCap` lists every place that can create authority.

```nim
import nimcs/fp/result
import nimcs/patterns/object_capability

let root = rootCap({rtRead, rtWrite})           # in main only
let reports = root.narrow("reports").value
let viewer = reports.readOnly                   # what a dashboard plugin is given
let store = emptyStore().write(reports, "reports/q1", "revenue 10").value
doAssert store.read(viewer, "reports/q1").value == "revenue 10"
doAssert store.write(viewer, "reports/q1", "x").error == ceDenied
doAssert store.read(viewer, "secrets/key").error == ceOutside
```

A callee can do exactly what the value it was handed allows, and a copy allows the same:

```nim
import nimcs/patterns/object_capability

func readable(store: Store; cap: FileCap; paths: openArray[string]): int {.raises: [].} =
  ## Counts the files this capability can read; it has no other way to reach the store.
  for p in paths:
    if store.read(cap, p).isOk: inc result

let admin = rootCap({rtRead, rtWrite})
let store = emptyStore().write(admin, "a/1", "x").value.write(admin, "b/1", "y").value
let paths = ["a/1", "b/1"]
doAssert readable(store, admin, paths) == 2
doAssert readable(store, admin.narrow("a").value, paths) == 1
doAssert readable(store, admin.restrict({}), paths) == 0
```

## Laws and invariants
- An attenuated capability never permits an operation its parent does not, and its rights are a subset of the parent's; a refused attenuation grants nothing (PAT-OBJCAP-01).
- Outside the module a `FileCap` cannot be built or defaulted, and every operation needs one as an argument (PAT-OBJCAP-02).
- Only whole segments below the prefix pass; dot, empty and absolute paths are refused (PAT-OBJCAP-03).
- Narrowing in two steps equals narrowing in one (PAT-OBJCAP-04).
- A read-only capability cannot write and leaves the store unchanged; writes return a new store (PAT-OBJCAP-05).
- A routine given a capability can do what that value allows and no more; a copy allows the same (PAT-OBJCAP-06).

## Complexity
`permits` and `narrow` are O(segments in the path or prefix); `read` and `write` add one persistent-map operation, O(log32 n).

## Pitfalls
Ambient authority: the callee reaches the resource by name, and a string role is checked instead:

```nim bad
var currentUser = "guest"                     # module-level state every function can read

proc deleteFile(path: string) =
  if currentUser == "admin":                  # ambient authority: who is asking is looked up, not held
    removeFile(path)
```

Fix: take a capability argument whose existence is the permission, and hand it out narrowed. Also do not build a capability from caller-supplied data (a role name, a flag) except at the powerbox, do not export a constructor for the sealed type, and do not widen: `narrow` takes a relative path and refuses `..` so that a narrower capability cannot reach back up.

## Related
- `singleton.md`, `dependency_record.md` (the global and the record this replaces or tightens)
- `caretaker.md` (revocable capabilities), `sealer_unsealer.md` (opaque tokens)
- `actor.md` (capabilities are what actors exchange in messages)
- `proxy.md` (wrapping a capability to narrow it)
- `smart_constructor` in nim-functional-core (the sealing technique)

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `ace3a1130eba6d54` Capability Myths Demolished
- `1e2d20b92c98ae15` Robust Composition (Miller thesis)
