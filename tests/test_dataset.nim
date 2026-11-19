## E tests for docs/specification.md NCK-DATA-01…NCK-DATA-04 (the dataset).

import std/[json, os, sets, strutils, unittest]
import nimcs/dataset

const root = currentSourcePath().parentDir.parentDir

const samplePage = """# Thing

## Intent
Why.

## Use when / avoid when
- when

## Nim shape
Module `src/nimcs/fp/thing.nim`.

## Public API

Generated.

```text
type Kind = enum
  one, two
const limit = 3
func f(x: int): int
```

## Laws and invariants
- `f(f(x)) == f(x)` (FP-THING-01)

## Complexity
O(1).

## Pitfalls
```nim bad
var x = 1
```
```nim
let x = 1
```

## Related
None.

## Sources
Catalog: 0123456789abcdef.
"""

# Kept in a .txt file so that spec_coverage does not read the sample tag as a real one.
const sampleTest = staticRead("fixtures/sample_test.txt")

const sampleModule = """## A thing.
## Second line.

type
  Kind* = enum
    one, two

const
  limit* = 3
  secret = 4

func f*(x: int): int {.raises: [].} =
  x

func hidden(x: int): int = x
"""

proc lines(path: string): seq[string] =
  for l in readFile(path).strip.splitLines: result.add l

suite "NCK-D dataset":
  let c = ConceptFiles(skill: "nim-functional-core", area: "fp", topic: "thing",
    pagePath: "skills/nim-functional-core/details/thing.md", page: samplePage,
    modulePath: "src/nimcs/fp/thing.nim", module: sampleModule,
    testPath: "tests/test_fp_thing.nim", test: sampleTest)

  # SPEC: NCK-DATA-01
  test "NCK-DATA-01 Given the same concepts in another order, when rendered twice, then the bytes are identical and ids unique":
    var c2 = c
    c2.topic = "other"
    let a = render(recordsOf(c) & recordsOf(c2))
    let b = render(recordsOf(c2) & recordsOf(c))
    check a == b
    var ids = initHashSet[string]()
    for l in a[0].strip.splitLines:
      let id = parseJson(l)["id"].getStr
      check id notin ids
      ids.incl id

  # SPEC: NCK-DATA-03
  test "NCK-DATA-03 Given a concept, when records are derived, then implement is the module verbatim, law the tagged test, refactor bad→good":
    let rs = recordsOf(c)
    var kinds: seq[RecordKind]
    for r in rs: kinds.add r.kind
    check kinds == @[rkExplain, rkImplement, rkRefactor, rkLaw]
    check rs[1].output == sampleModule
    # The signatures come from the page's generated Public API section (NCK-KNOW-06 checks it).
    check "```nim\ntype Kind = enum\n  one, two\nconst limit = 3\nfunc f(x: int): int\n```" in rs[1].instruction
    check "Generated." notin rs[1].instruction
    check "A thing." in rs[1].instruction
    check rs[2].input == "var x = 1\n"
    check rs[2].output == "let x = 1\n"
    check rs[3].output.startsWith(sampleTest.splitLines[1].strip & "\ntest \"FP-THING-01")
    check "other" notin rs[3].output
    check rs[3].specIds == @["FP-THING-01"]
    for r in rs: check r.sources == @["0123456789abcdef"]

  # SPEC: NCK-DATA-02
  test "NCK-DATA-02 Given the committed dataset, when read, then every record has the fields, a known kind, and existing files and spec IDs":
    let path = root / "dataset" / "records.jsonl"
    check fileExists(path)
    var specText = readFile(root / "docs" / "specification.md")
    for f in walkFiles(root / "docs" / "spec" / "*.md"): specText.add readFile(f)
    var n = 0
    for l in lines(path):
      inc n
      let j = parseJson(l)
      for k in ["id", "kind", "area", "concept", "instruction", "input", "output", "specIds", "sources", "files"]:
        check j.hasKey(k)
      check j["kind"].getStr in ["explain", "implement", "refactor", "law"]
      check j["instruction"].getStr.len > 0
      check j["output"].getStr.len > 0
      for f in j["files"]: check fileExists(root / f.getStr)
      for s in j["specIds"]:
        if ("| " & s.getStr & " |") notin specText: checkpoint j["id"].getStr & ": " & s.getStr
        check ("| " & s.getStr & " |") in specText
    check n > 0

  # SPEC: NCK-DATA-01
  test "NCK-DATA-01 Given the repository, when the dataset is rebuilt, then it equals the committed one":
    let tmp = getTempDir() / "nck-dataset-rebuild"
    removeDir(tmp)
    let rc = execShellCmd(quoteShell(root / "bin" / "dataset_build") & " --out:" & quoteShell(tmp) & " > /dev/null")
    check rc == 0
    for f in ["records.jsonl", "chat.jsonl"]:
      check readFile(tmp / f) == readFile(root / "dataset" / f)

  # SPEC: NCK-DATA-04
  test "NCK-DATA-04 Given the committed chat file, when read, then each line has system, user, assistant and matches a record":
    let recs = lines(root / "dataset" / "records.jsonl")
    let chats = lines(root / "dataset" / "chat.jsonl")
    check recs.len == chats.len
    for i, l in chats:
      let j = parseJson(l)
      check j["id"].getStr == parseJson(recs[i])["id"].getStr
      var roles: seq[string]
      for m in j["messages"]: roles.add m["role"].getStr
      check roles == @["system", "user", "assistant"]
