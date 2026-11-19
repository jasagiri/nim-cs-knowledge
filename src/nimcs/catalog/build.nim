## Assembling the catalog from fetched pages held in memory (NCK-CAT-01…C7). Pure: the same inputs
## give the same bytes (NCK-CAT-06); tools/catalog_build.nim only reads the files and writes the result.

import std/[algorithm, json, strutils, tables]
import ./[model, fpb, hillside, links, triage]

type
  Reachability* = object
    status*: Reach
    code*: int
    final*: string ## the URL after redirects, when it differs

  Expansion* = object
    ## A depth-1 list fetched for its own links (NCK-CAT-04).
    listId*: string
    base*: string ## the URL its relative links resolve against
    markdown*: bool
    body*: string

  BuildInputs* = object
    fpbCommit*: string
    fetchedAt*: string ## from raw/manifest.json, never the clock (NCK-CAT-06)
    fpbFiles*: seq[(string, string)] ## path relative to the fpb root, text
    catalogPages*: seq[string] ## hillside catalog pages, any order
    bookPages*: seq[(string, string)] ## hillside category, html
    weblinkTargets*: Table[int, string] ## hillside weblink id → redirect target
    reach*: Table[string, Reachability] ## source id → result of the reachability check
    expansions*: seq[Expansion]
    overrides*: Table[string, Relevance] ## source id → class decided by hand

  BuildOutput* = object
    sources*: seq[Source]
    relevance*: Table[string, Relevance]
    notFollowed*: seq[(string, string)] ## meta-list id, reason
    metaJson*: string
    sourcesJsonl*: string
    triageJson*: string

const
  MaxLinksPerExpansion* = 2000
  ListFiles = ["books/", "courses/", "more/", "casts/"]

func isMetaListing(l: Listing): bool {.raises: [].} =
  for h in l.section:
    if "meta-list" in h.toLowerAscii or "meta list" in h.toLowerAscii: return true

func expandable*(s: Source): bool {.raises: [].} =
  ## Which depth-1 entries are themselves lists we follow one more level (NCK-CAT-04): every hillside
  ## web link (each is an external pattern catalog), and fpb meta-lists kept on GitHub (a README
  ## that is one page of links). Other meta-lists are whole sites; they are recorded, not crawled.
  for l in s.listings:
    if l.depth != 1: continue
    if l.origin == oHillside and "/patterns/books/" notin s.url: return true
    if l.origin == oFpb and isMetaListing(l) and s.url.startsWith("https://github.com/"): return true

func notFollowedReason*(s: Source): string {.raises: [].} =
  ## Why a meta-list was not followed, or "" when it was a candidate or is not a meta-list.
  for l in s.listings:
    if l.origin == oFpb and l.depth == 1 and isMetaListing(l) and not expandable(s):
      return "meta-list is a whole site, not one page of links"

func githubReadmeUrl*(repoUrl: string): string {.raises: [].} =
  ## https://github.com/o/r[/...] → https://raw.githubusercontent.com/o/r/HEAD/README.md
  let parts = repoUrl.split('/')
  if parts.len < 5: return ""
  "https://raw.githubusercontent.com/" & parts[3] & "/" & parts[4] & "/HEAD/README.md"

func toJson(l: Listing): JsonNode {.raises: [].} =
  var section: seq[string]
  for h in l.section: section.add validUtf8(h)
  result = %*{"origin": $l.origin, "file": validUtf8(l.file), "section": section, "depth": l.depth}
  if l.via.len > 0: result["via"] = %l.via

func toJson(s: Source; r: Reachability; rel: Relevance): JsonNode {.raises: [].} =
  result = %*{"id": $s.id, "url": validUtf8(s.url), "title": validUtf8(s.title)}
  if s.authors.len > 0: result["authors"] = %validUtf8(s.authors)
  if s.formats.len > 0: result["formats"] = %s.formats
  if s.licenses.len > 0: result["licenses"] = %s.licenses
  if s.archived: result["archived"] = %true
  result["lang"] = %s.lang
  result["relevance"] = %($rel)
  result["reach"] = %($r.status)
  if r.code != 0: result["httpCode"] = %r.code
  if r.final.len > 0: result["finalUrl"] = %validUtf8(r.final)
  var ls = newJArray()
  for l in s.listings: ls.add toJson(l)
  result["listings"] = ls

func fpbSources(inputs: BuildInputs): seq[Source] {.raises: [].} =
  for (path, text) in inputs.fpbFiles:
    var listed = false
    for d in ListFiles:
      if path.startsWith(d): listed = true
    if listed and path.endsWith(".md"):
      result.add parseList(path, text)

func hillsideSources(inputs: BuildInputs): seq[Source] {.raises: [].} =
  for page in inputs.catalogPages:
    for w in parseCatalogPage(page).links:
      let target = inputs.weblinkTargets.getOrDefault(w.linkId, "")
      let url = if target.len > 0: target else: weblinkUrl(w.linkId)
      result.add Source(id: sourceIdOf(url), url: url, title: w.title, lang: "en",
        listings: @[Listing(origin: oHillside, file: CatalogPath, depth: 1,
                            section: @["Patterns Catalog"])])
  for (category, html) in inputs.bookPages:
    for a in parseBookCategory(html, category):
      result.add Source(id: sourceIdOf(a.href), url: a.href, title: a.text, lang: "en",
        listings: @[Listing(origin: oHillside, file: "/patterns/books/" & category, depth: 1,
                            section: @["Books", category])])

func expansionSources(inputs: BuildInputs; depth1: Table[string, Source]): seq[Source] {.raises: [].} =
  for e in inputs.expansions:
    if e.listId notin depth1: continue
    let parent = depth1.getOrDefault(e.listId)
    let anchors = if e.markdown: markdownAnchors(e.body, e.base) else: htmlAnchors(e.body, e.base)
    var n = 0
    for a in anchors:
      if n >= MaxLinksPerExpansion: break
      if not isWebLink(a.href) or a.text.len == 0: continue
      if normalizeUrl(a.href) == normalizeUrl(parent.url): continue
      inc n
      let origin = parent.listings[0].origin
      result.add Source(id: sourceIdOf(a.href), url: a.href, title: a.text, lang: parent.lang,
        listings: @[Listing(origin: origin, file: parent.url, depth: 2, via: e.listId,
                            section: @[parent.title])])

func assemble*(inputs: BuildInputs): BuildOutput {.raises: [].} =
  var depth1 = dedupe(fpbSources(inputs) & hillsideSources(inputs))
  var byId = initTable[string, Source]()
  for s in depth1: byId[$s.id] = s
  let all = dedupe(depth1 & expansionSources(inputs, byId))
  result.sources = all
  var counts = initTable[string, int]()
  var lines = newSeqOfCap[string](all.len)
  var classes: array[Relevance, seq[string]]
  for s in all:
    let id = $s.id
    let rel = if id in inputs.overrides: inputs.overrides.getOrDefault(id) else: classify(s)
    result.relevance[id] = rel
    classes[rel].add id
    let r = inputs.reach.getOrDefault(id, Reachability(status: rUnchecked))
    counts.mgetOrPut("reach." & $r.status, 0).inc
    for l in s.listings:
      counts.mgetOrPut("listings.depth" & $l.depth, 0).inc
    lines.add $toJson(s, r, rel)
    let why = notFollowedReason(s)
    if why.len > 0: result.notFollowed.add (id, why)
  result.sourcesJsonl = lines.join("\n") & "\n"
  var countKeys: seq[string]
  for k in counts.keys: countKeys.add k
  countKeys.sort()
  var countsJson = newJObject()
  countsJson["sources"] = %all.len
  for r in Relevance: countsJson["relevance." & $r] = %classes[r].len
  for k in countKeys: countsJson[k] = %counts.getOrDefault(k)
  var nf = newJArray()
  for (id, why) in result.notFollowed: nf.add %*{"id": id, "reason": why}
  let meta = %*{
    "fpbCommit": inputs.fpbCommit,
    "fetchedAt": inputs.fetchedAt,
    "depthLimit": 2,
    "maxLinksPerExpansion": MaxLinksPerExpansion,
    "counts": countsJson,
    "notFollowed": nf}
  result.metaJson = meta.pretty & "\n"
  var tri = newJObject()
  for r in Relevance:
    tri[$r] = %classes[r]
  result.triageJson = tri.pretty & "\n"
