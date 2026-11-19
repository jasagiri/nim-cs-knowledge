# Adapter

## Intent
Existing code produces or expects one shape; the new code uses another. The OO pattern wraps an
object in a class that implements the interface the client expects. In Nim the "interface" is a
type, so the adapter is a **func between two types**. Adapting a source of values is mapping that
func over what the source returns.

## Use when / avoid when
- Use at the boundary where a foreign shape enters (legacy strings, a third-party record, a wire
  format): convert once, then use only the domain type inside.
- Make the conversion total: return a `Result` with a specific error, never raise.
- Avoid adapting in place deep inside the code, so that the foreign shape spreads.
- Avoid an adapter class holding the adaptee as a field with forwarding methods: a func does it.

## Nim shape
A legacy schedule source gives `"HH:MM"` strings; the new code works with `Minutes`. `fromLegacy`
and `toLegacy` are the two directions; `adaptAll` adapts a whole source.

Module: `src/nimcs/patterns/adapter.nim`.

```nim
import nimcs/fp/result
import nimcs/patterns/adapter

doAssert fromLegacy("07:05").value == Minutes(425)
doAssert toLegacy(Minutes(425)) == "07:05"
doAssert fromLegacy("7:05").error == aeBadLength
doAssert fromLegacy("24:00").error == aeOutOfRange

let legacy: LegacySource = proc(): seq[string] {.noSideEffect, raises: [].} =
  @["09:00", "17:30"]
doAssert adaptAll(legacy).value == @[Minutes(540), Minutes(1050)]
```

## Laws and invariants
- For any minute of the day, `fromLegacy(toLegacy(m))` is `m`; when parsing succeeds, formatting
  returns the same string (GOF-ADAPTER-01).
- Malformed strings are rejected with the specific error (length, separator, digit, range)
  (GOF-ADAPTER-02).
- `adaptAll` equals mapping `fromLegacy` over the source's output and stops at the first bad entry
  (GOF-ADAPTER-03).

## Complexity
O(length of the input) per conversion; `adaptAll` is O(total length). No allocation besides the result.

## Pitfalls
Parsing with the standard library's raising parsers inside a `{.raises: [].}` func forces a hidden
`try/except` that swallows the reason.

```nim bad
import std/strutils

func minutes(s: string): int =
  try:
    parseInt(s[0 .. 1]) * 60 + parseInt(s[3 .. 4])
  except ValueError:
    0          # a bad input silently becomes midnight
```

Return the failure as a value:

```nim
import nimcs/fp/result

func twoDigits(s: string): Result[int, string] =
  if s.len == 2 and s[0] in {'0' .. '9'} and s[1] in {'0' .. '9'}:
    ok((ord(s[0]) - 48) * 10 + (ord(s[1]) - 48), string)
  else:
    err(int, "not two digits")

doAssert twoDigits("07").value == 7
doAssert twoDigits("7x").isErr
```

## Related
- `proxy.md` (same interface, different behaviour), `facade.md` (a simpler interface over many), `decorator.md`.

## Sources

Catalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:

- `25f90d554113e6d5` Scala & Design Patterns: Exploring Language Expressivity
- `0789f21330e7f72a` Source Making Design Patterns and UML
- `690b10bb5f31ac02` The Catalog of Design Patterns
