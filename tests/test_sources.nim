## E tests for docs/specification.md NCK-SRC-01 and NCK-SRC-02 (ADR-NCK-0005): every source the
## repository lists is under a licence that allows commercial use.

import std/[json, os, sets, unittest]
import free_books_catalog/licences

const root = currentSourcePath().parentDir.parentDir

proc catalogLines(): seq[JsonNode] =
  for line in lines(root / "catalog" / "sources.jsonl"):
    if line.len > 0: result.add parseJson(line)

suite "sources":
  # SPEC: NCK-SRC-01
  test "NCK-SRC-01 Given the catalog, when each source is read, then it states licences and every one allows commercial use":
    let allowed = commercialLicenses.toHashSet
    let sources = catalogLines()
    check sources.len > 0
    for s in sources:
      let lic = s{"licenses"}
      checkpoint s["id"].getStr & " " & s["url"].getStr
      check lic != nil and lic.len > 0
      if lic != nil:
        for l in lic:
          check l.getStr in allowed

  # SPEC: NCK-SRC-02
  test "NCK-SRC-02 Given the catalog config, when read, then free-programming-books and Hillside are off, commercialOnly is on and the catalog holds the listed sources only":
    let c = parseJson(readFile(root / "catalog" / "config.json"))
    check not c["fpb"].getBool
    check not c["hillside"].getBool
    check c["commercialOnly"].getBool
    var listed = initHashSet[string]()
    for x in c["listed"]: listed.incl x["url"].getStr
    var inCatalog = initHashSet[string]()
    for s in catalogLines(): inCatalog.incl s["url"].getStr
    check inCatalog == listed

  # SPEC: NCK-SRC-03
  test "NCK-SRC-03 Given catalog/citations.json, when read, then every page has an entry, every cited URL is a listed source and every listed source is cited":
    let cj = parseJson(readFile(root / "catalog" / "citations.json"))["pages"]
    var pages = initHashSet[string]()
    for (skill, area) in [("nim-functional-core", "fp"), ("nim-data-structures", "ds"),
                          ("nim-algorithms", "algo"), ("nim-design-patterns", "patterns")]:
      for f in walkFiles(root / "skills" / skill / "details" / "*.md"):
        pages.incl area & "/" & f.extractFilename.changeFileExt("")
    var keys = initHashSet[string]()
    for k, _ in cj.pairs: keys.incl k
    check keys == pages
    var cited = initHashSet[string]()
    for _, v in cj.pairs:
      if v["sources"].len == 0: check v{"note"}.getStr.len > 0
      for s in v["sources"]: cited.incl s["url"].getStr
    var listed = initHashSet[string]()
    for x in parseJson(readFile(root / "catalog" / "config.json"))["listed"]: listed.incl x["url"].getStr
    check cited == listed
