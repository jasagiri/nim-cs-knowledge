## The details pages and the module, test and area each belongs to; shared by the tools that read
## pages (dataset_build, api_sections), so both find a page's module the same way.

import std/[algorithm, os, strutils]
import nimcs/dataset

const SkillArea* = [("nim-functional-core", "fp"), ("nim-data-structures", "ds"),
                   ("nim-algorithms", "algo"), ("nim-design-patterns", "patterns")]

proc moduleOf*(root, area, page, stem: string): string =
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
