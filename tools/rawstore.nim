## The fetched pages on disk (raw/) and its manifest, shared by catalog_fetch and catalog_build.
## raw/ is a cache outside the repository ($NIMCS_RAW, default ~/.cache/nim-cs-knowledge/raw); it
## is never committed. Everything the build needs is in it, so the build never touches the network.
##
## Layout:
##   fpb/                         free-programming-books at manifest.fpbCommit
##   hillside/catalog-<start>.html, hillside/books-<category>.html
##   expand/<source id>.html|.md  depth-1 lists fetched for their links
##   manifest.json                what was fetched, when, and the results of checks

import std/[algorithm, json, os, strutils, tables]
import nimcs/catalog/[build, model, triage]

const ManifestName* = "manifest.json"

type Manifest* = object
  fpbCommit*: string
  fetchedAt*: string
  weblinks*: Table[int, string]
  reach*: Table[string, Reachability]
  expansions*: seq[(string, string, bool, string)] ## list id, base url, markdown?, file under raw/

proc defaultRaw*(): string =
  getEnv("NIMCS_RAW", getHomeDir() / ".cache" / "nim-cs-knowledge" / "raw")

proc loadManifest*(raw: string): Manifest {.raises: [IOError, OSError, ValueError].} =
  ## The manifest, or an empty one when raw/ has none yet. A manifest that is not valid JSON is an
  ## error, not an empty manifest: silently starting over would refetch everything.
  let path = raw / ManifestName
  if not fileExists(path): return
  let j = try: parseJson(readFile(path))
          except JsonParsingError as e: raise newException(ValueError, path & ": " & e.msg)
  result.fpbCommit = j{"fpbCommit"}.getStr
  result.fetchedAt = j{"fetchedAt"}.getStr
  if j.hasKey("weblinks"):
    for k, v in j["weblinks"].pairs:
      result.weblinks[parseInt(k)] = v.getStr
  if j.hasKey("reach"):
    for k, v in j["reach"].pairs:
      result.reach[k] = Reachability(status: parseEnum[Reach](v{"status"}.getStr("unchecked")),
        code: v{"code"}.getInt, final: v{"final"}.getStr)
  if j.hasKey("expansions"):
    for e in j["expansions"]:
      result.expansions.add (e{"listId"}.getStr, e{"base"}.getStr, e{"markdown"}.getBool,
        e{"file"}.getStr)

proc saveManifest*(raw: string; m: Manifest) {.raises: [IOError].} =
  var weblinks = newJObject()
  var ids: seq[int]
  for k in m.weblinks.keys: ids.add k
  for k in ids.sorted: weblinks[$k] = %m.weblinks.getOrDefault(k)
  var reach = newJObject()
  var keys: seq[string]
  for k in m.reach.keys: keys.add k
  for k in keys.sorted:
    let r = m.reach.getOrDefault(k)
    var o = %*{"status": $r.status}
    if r.code != 0: o["code"] = %r.code
    if r.final.len > 0: o["final"] = %r.final
    reach[k] = o
  var exps = newJArray()
  for (id, base, md, file) in m.expansions:
    exps.add %*{"listId": id, "base": base, "markdown": md, "file": file}
  let j = %*{"fpbCommit": m.fpbCommit, "fetchedAt": m.fetchedAt, "weblinks": weblinks,
             "reach": reach, "expansions": exps}
  writeFile(raw / ManifestName, j.pretty & "\n")

proc readInputs*(raw: string; overridesFile: string): BuildInputs {.raises: [IOError, OSError, ValueError].} =
  ## Everything under raw/ as BuildInputs, files in sorted order so the result does not depend
  ## on the directory's listing order (NCK-CAT-06).
  let m = loadManifest(raw)
  result.fpbCommit = m.fpbCommit
  result.fetchedAt = m.fetchedAt
  result.weblinkTargets = m.weblinks
  result.reach = m.reach
  let fpbRoot = raw / "fpb"
  var files: seq[string]
  for dir in ["books", "courses", "more", "casts"]:
    for f in walkFiles(fpbRoot / dir / "*.md"): files.add f
  for f in files.sorted:
    result.fpbFiles.add (f.relativePath(fpbRoot), readFile(f))
  var pages: seq[string]
  for f in walkFiles(raw / "hillside" / "catalog-*.html"): pages.add f
  for f in pages.sorted: result.catalogPages.add readFile(f)
  var books: seq[string]
  for f in walkFiles(raw / "hillside" / "books-*.html"): books.add f
  for f in books.sorted:
    let cat = f.extractFilename.changeFileExt("")["books-".len .. ^1]
    result.bookPages.add (cat, readFile(f))
  for (id, base, md, file) in m.expansions:
    if file.len > 0 and fileExists(raw / file):
      result.expansions.add Expansion(listId: id, base: base, markdown: md, body: readFile(raw / file))
  if overridesFile.len > 0 and fileExists(overridesFile):
    let j = try: parseJson(readFile(overridesFile))
            except JsonParsingError as e: raise newException(ValueError, overridesFile & ": " & e.msg)
    for k, v in j.pairs:
      result.overrides[k] = parseEnum[Relevance](v.getStr)
