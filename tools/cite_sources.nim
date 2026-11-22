## cite_sources [--root:<repo>]
##
## Rewrites the Sources section of every details page from catalog/citations.json and
## catalog/sources.jsonl (ADR-NCK-0005). Idempotent: a second run changes nothing. Pages are keyed
## `<area>/<page name>`; each key lists the URLs of the sources that explain its concept, in the
## order they are cited, with what each covers, and a note: why none does, or what the cited
## sources leave out. `original` says which writing is the repository's own: "all" (no source
## explains the concept) or "part" (what the note says the sources leave out); each becomes an
## "Original writing:" paragraph. Exit 1 when a cited URL is not in the catalog, a page has no key,
## or `original` does not match the sources (ADR-NCK-0005), 2 on a usage error.

import std/[json, os, parseopt, strutils, tables]

const SkillArea = [("nim-functional-core", "fp"), ("nim-data-structures", "ds"),
                   ("nim-algorithms", "algo"), ("nim-design-patterns", "patterns")]

type Cited = object
  id, title, covers: string

const
  allOriginal = "Original writing: this page was written for this repository. No source under a " &
    "licence that allows commercial use was found that explains its concept; what the page claims " &
    "rests on its module's tests."
  partOriginal = "Original writing: what the note above says the cited sources leave out was " &
    "written for this repository; it rests on the module's tests."

func sourcesSection(cited: seq[Cited]; note, original: string): string =
  if cited.len == 0:
    return "## Sources\n\nNone in the catalog: " & note.strip & "\n\n" & allOriginal & "\n"
  result = "## Sources\n\nCatalog IDs (catalog/sources.jsonl) of sources that explain this concept, " &
    "each under a licence that allows commercial use:\n\n"
  for s in cited:
    result.add "- `" & s.id & "` " & s.title.replace("\n", " ")
    if s.covers.len > 0: result.add ": " & s.covers.strip.replace("\n", " ")
    result.add "\n"
  if note.strip.len > 0: result.add "\n" & note.strip & "\n"
  if original == "part": result.add "\n" & partOriginal & "\n"

func replaceSources*(page, section: string): string =
  ## `page` with everything from "## Sources" to the end replaced by `section`.
  let at = page.find("\n## Sources")
  if at < 0: page.strip(leading = false) & "\n\n" & section
  else: page[0 .. at] & section

proc main(): int =
  var root = currentSourcePath().parentDir.parentDir
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "root": root = val
      else:
        stderr.writeLine "cite_sources: unknown option --" & key
        return 2
    of cmdArgument:
      stderr.writeLine "cite_sources: unexpected argument " & key
      return 2
    of cmdEnd: discard # getopt never yields cmdEnd inside the loop
  var byUrl = initTable[string, tuple[id, title: string]]()
  for line in lines(root / "catalog" / "sources.jsonl"):
    let j = parseJson(line)
    byUrl[j["url"].getStr] = (j["id"].getStr, j["title"].getStr)
  let pagesJ = parseJson(readFile(root / "catalog" / "citations.json"))["pages"]
  var changed = 0
  for (skill, area) in SkillArea:
    for f in walkFiles(root / "skills" / skill / "details" / "*.md"):
      let key = area & "/" & f.extractFilename.changeFileExt("")
      if not pagesJ.hasKey(key):
        stderr.writeLine "cite_sources: ", key, " has no entry in catalog/citations.json"
        return 1
      var cited: seq[Cited]
      for s in pagesJ[key]["sources"]:
        let url = s["url"].getStr
        if url notin byUrl:
          stderr.writeLine "cite_sources: ", key, ": ", url, " is not in the catalog"
          return 1
        cited.add Cited(id: byUrl[url].id, title: byUrl[url].title, covers: s{"covers"}.getStr)
      let original = pagesJ[key]{"original"}.getStr
      let note = pagesJ[key]{"note"}.getStr
      if (cited.len == 0) != (original == "all") or original notin ["", "all", "part"] or
          (original == "part" and note.strip.len == 0):
        stderr.writeLine "cite_sources: ", key, ": original is \"", original,
          "\"; it must be \"all\" exactly when no source is cited, and \"part\" needs a note"
        return 1
      let page = readFile(f)
      let updated = replaceSources(page, sourcesSection(cited, note, original))
      if updated != page:
        writeFile(f, updated)
        inc changed
  echo "cite_sources: ", changed, " pages updated"
  0

when isMainModule:
  quit main()
