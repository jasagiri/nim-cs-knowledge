## dataset_build [--root:<repo>] [--out:<dir>]
##
## skills/*/details/*.md + their modules and tests → dataset/records.jsonl and dataset/chat.jsonl
## (ADR-NCK-0003). No network, no clock (NCK-DATA-01). Exit 0 on success, 2 on a usage error.

import std/[algorithm, os, parseopt, strutils]
import nimcs/dataset

const SkillArea = [("nim-functional-core", "fp"), ("nim-data-structures", "ds"),
                   ("nim-algorithms", "algo"), ("nim-design-patterns", "patterns")]

proc moduleOf(root, area, page, stem: string): string =
  ## The module a page names in its Nim shape section (`src/nimcs/<area>/<name>.nim`), or the module
  ## named like the page; "" when neither exists.
  let marker = "src/nimcs/" & area & "/"
  var at = page.find(marker)
  while at >= 0:
    var stop = at + marker.len
    while stop < page.len and page[stop] in IdentChars: inc stop
    if page.continuesWith(".nim", stop):
      let rel = page[at ..< stop + 4]
      if fileExists(root / rel): return rel
    at = page.find(marker, at + 1)
  let guess = marker & stem & ".nim"
  if fileExists(root / guess): guess else: ""

proc collect*(root: string): seq[ConceptFiles] =
  for (skill, area) in SkillArea:
    var pages: seq[string]
    for f in walkFiles(root / "skills" / skill / "details" / "*.md"): pages.add f
    for f in pages.sorted:
      let stem = f.extractFilename.changeFileExt("")
      var c = ConceptFiles(skill: skill, area: area, topic: stem,
        pagePath: f.relativePath(root), page: readFile(f))
      c.modulePath = moduleOf(root, area, c.page, stem)
      if c.modulePath.len > 0:
        c.module = readFile(root / c.modulePath)
        let t = "tests/test_" & area & "_" & c.modulePath.extractFilename
        if fileExists(root / t):
          c.testPath = t
          c.test = readFile(root / t)
      result.add c

proc main(): int =
  var root = currentSourcePath().parentDir.parentDir
  var outDir = ""
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "root": root = val
      of "out": outDir = val
      else:
        stderr.writeLine "dataset_build: unknown option --" & key
        return 2
    of cmdArgument:
      stderr.writeLine "dataset_build: unexpected argument " & key
      return 2
    of cmdEnd: discard # getopt never yields cmdEnd inside the loop
  if outDir.len == 0: outDir = root / "dataset"
  var records: seq[Record]
  for c in collect(root): records.add recordsOf(c)
  let (recs, chat) = render(records)
  createDir(outDir)
  writeFile(outDir / "records.jsonl", recs)
  writeFile(outDir / "chat.jsonl", chat)
  echo "dataset_build: ", records.len, " records → ", outDir
  0

when isMainModule:
  quit main()
