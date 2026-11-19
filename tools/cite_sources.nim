## cite_sources [--root:<repo>] [--max:<n>]
##
## Rewrites the Sources section of every details page from catalog/concepts.json and
## catalog/sources.jsonl (ADR-NCK-0001). Idempotent: a second run changes nothing. Pages are keyed
## `<area>/<page name>`. At most --max sources per page (default 8), English depth-1 sources first,
## then by title, so the choice is stable.

import std/[algorithm, json, os, parseopt, strutils, tables]

const SkillArea = [("nim-functional-core", "fp"), ("nim-data-structures", "ds"),
                   ("nim-algorithms", "algo"), ("nim-design-patterns", "patterns")]

type Src = object
  id, title, lang: string
  depth: int

func sourcesSection(cited: seq[Src]; examined: int): string =
  if cited.len == 0:
    return "## Sources\n\nNone in the catalog: no table of contents among the " & $examined &
      " core sources examined so far (catalog/concepts.json) names this concept.\n"
  result = "## Sources\n\nCatalog IDs (catalog/sources.jsonl) whose table of contents covers this concept:\n\n"
  for s in cited:
    result.add "- `" & s.id & "` " & s.title.replace("\n", " ") & "\n"

func replaceSources*(page, section: string): string =
  ## `page` with everything from "## Sources" to the end replaced by `section`.
  let at = page.find("\n## Sources")
  if at < 0: page.strip(leading = false) & "\n\n" & section
  else: page[0 .. at] & section

proc main(): int =
  var root = currentSourcePath().parentDir.parentDir
  var most = 8
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "root": root = val
      of "max": most = parseInt(val)
      else:
        stderr.writeLine "cite_sources: unknown option --" & key
        return 2
    of cmdArgument:
      stderr.writeLine "cite_sources: unexpected argument " & key
      return 2
    of cmdEnd: discard # getopt never yields cmdEnd inside the loop
  var byId = initTable[string, Src]()
  for line in lines(root / "catalog" / "sources.jsonl"):
    let j = parseJson(line)
    byId[j["id"].getStr] = Src(id: j["id"].getStr, title: j["title"].getStr, lang: j["lang"].getStr,
      depth: j["listings"][0]["depth"].getInt)
  let cj = parseJson(readFile(root / "catalog" / "concepts.json"))
  let examined = cj["examined"].len
  var changed = 0
  for (skill, area) in SkillArea:
    for f in walkFiles(root / "skills" / skill / "details" / "*.md"):
      let key = area & "/" & f.extractFilename.changeFileExt("")
      var cited: seq[Src]
      if cj["concepts"].hasKey(key):
        for id in cj["concepts"][key]:
          if id.getStr in byId: cited.add byId[id.getStr]
          else:
            stderr.writeLine "cite_sources: ", key, ": ", id.getStr, " is not in the catalog"
            return 1
      cited.sort(proc(a, b: Src): int =
        result = cmp(a.lang != "en", b.lang != "en")
        if result == 0: result = cmp(a.depth, b.depth)
        if result == 0: result = cmp(a.title.toLowerAscii, b.title.toLowerAscii)
        if result == 0: result = cmp(a.id, b.id))
      if cited.len > most: cited.setLen(most)
      let page = readFile(f)
      let updated = replaceSources(page, sourcesSection(cited, examined))
      if updated != page:
        writeFile(f, updated)
        inc changed
  echo "cite_sources: ", changed, " pages updated"
  0

when isMainModule:
  quit main()
