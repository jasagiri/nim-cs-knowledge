## catalog_fetch <step> [--raw:<dir>] [--commit:<sha>] [--hosts:<n>] [--delay:<ms>]
##
## The only part of the repository that uses the network (NCK-CAT-07). Steps, in order:
##   fpb       free-programming-books at --commit (a full SHA) into raw/fpb
##   hillside  every page of the Patterns Catalog, the eight Books categories, and the redirect
##             target of every catalog web link
##   expand    the depth-1 lists that build.expandable selects, each one page (NCK-CAT-04)
##   reach     a HEAD (GET when HEAD is refused) on every core depth-1 source (NCK-CAT-05)
## Each step records what it did in raw/manifest.json. Requests to one host are sequential with
## --delay between them (default 1000 ms), at most --hosts hosts at once (default 8), robots.txt
## is honoured for the user agent "*", and every failure is recorded as a state, never dropped.
## Exit 0 when the step ran (individual URLs may still have failed: see the manifest), 1 when the
## step could not run, 2 on a usage error.

import std/[asyncdispatch, httpclient, os, osproc, parseopt, sets, strutils, tables, times, uri]
import nimcs/catalog/[build, hillside, model, triage]
import ./rawstore

const
  UserAgent = "nim-cs-knowledge-catalog/0.1 (catalog of free programming books; one request per host at a time)"
  TimeoutMs = 20_000
  MaxRedirects = 5
  FpbRepo = "EbookFoundation/free-programming-books"

type
  Settings = object
    raw: string
    commit: string
    hosts: int
    delayMs: int

  Robots = seq[string] ## Disallow prefixes for "*"

proc nowStamp(): string = now().utc.format("yyyy-MM-dd'T'HH:mm:ss'Z'")

proc parseRobots(text: string): Robots =
  var applies = false
  for raw in text.splitLines:
    let line = raw.split('#')[0].strip
    let colon = line.find(':')
    if colon < 0: continue
    let key = line[0 ..< colon].strip.toLowerAscii
    let val = line[colon + 1 .. ^1].strip
    if key == "user-agent": applies = val == "*"
    elif key == "disallow" and applies and val.len > 0: result.add val

proc allowed(r: Robots; url: string): bool =
  let path = try: parseUri(url).path except UriParseError: "/"
  for p in r:
    if path.startsWith(p): return false
  true

proc fetchOnce(url: string; httpMethod: HttpMethod): Future[(int, string, string)] {.async.} =
  ## (status code, Location header, body); body only for GET. Code 0 with the message in the
  ## body on a transport error or timeout.
  let client = newAsyncHttpClient(userAgent = UserAgent, maxRedirects = 0)
  try:
    let fut = client.request(url, httpMethod = httpMethod)
    if not await fut.withTimeout(TimeoutMs):
      return (0, "", "timeout")
    let resp = fut.read
    let code = resp.code.int
    let location = resp.headers.getOrDefault("location")
    var body = ""
    if httpMethod == HttpGet:
      body = await resp.body
    return (code, $location, body)
  except CatchableError as e:
    return (0, "", $e.name & ": " & e.msg)
  finally:
    client.close()

proc follow(url: string; httpMethod: HttpMethod): Future[(int, string, string)] {.async.} =
  ## Follows up to MaxRedirects redirects: (final code, final URL, body).
  var cur = url
  for _ in 0 .. MaxRedirects:
    let (code, location, body) = await fetchOnce(cur, httpMethod)
    if code in 300 .. 399 and location.len > 0:
      cur = $combine(parseUri(cur), parseUri(location))
      continue
    return (code, cur, body)
  return (310, cur, "too many redirects")

proc classifyReach(code: int; url, final: string): Reachability =
  let finalUrl = if normalizeUrl(final) != normalizeUrl(url): final else: ""
  case code
  of 0: Reachability(status: rError)
  of 200 .. 299:
    Reachability(status: (if finalUrl.len > 0: rRedirected else: rOk), code: code, final: finalUrl)
  of 401, 403, 429: Reachability(status: rRefused, code: code)
  else: Reachability(status: rDead, code: code, final: finalUrl)

type Job = object
  key: string ## source id (reach) or list id (expand)
  url: string

proc hostOf(url: string): string =
  try: parseUri(url).hostname.toLowerAscii except UriParseError: ""

proc runHost(jobs: seq[Job]; delayMs: int; get: bool;
             results: ref Table[string, (int, string, string)]) {.async.} =
  ## The jobs of one host, one after another, robots.txt first.
  if jobs.len == 0: return
  let first = parseUri(jobs[0].url)
  let (rc, _, rbody) = await follow(first.scheme & "://" & first.hostname & "/robots.txt", HttpGet)
  let robots = if rc in 200 .. 299: parseRobots(rbody) else: @[]
  for i, j in jobs:
    if i > 0: await sleepAsync(delayMs)
    if not robots.allowed(j.url):
      results[][j.key] = (-1, j.url, "robots.txt disallows")
      continue
    var r = await follow(j.url, if get: HttpGet else: HttpHead)
    if not get and r[0] in [0, 400, 403, 405, 501]:
      # Many servers refuse HEAD; ask again with GET before calling the source unreachable.
      await sleepAsync(delayMs)
      r = await follow(j.url, HttpGet)
      r[2] = ""
    results[][j.key] = r

proc runAll(jobs: seq[Job]; s: Settings; get: bool): Table[string, (int, string, string)] =
  var byHost = initOrderedTable[string, seq[Job]]()
  for j in jobs:
    byHost.mgetOrPut(hostOf(j.url), @[]).add j
  let results = new Table[string, (int, string, string)]
  var hosts: seq[seq[Job]]
  for v in byHost.values: hosts.add v
  var i = 0
  while i < hosts.len:
    var futs: seq[Future[void]]
    for k in i ..< min(i + s.hosts, hosts.len):
      futs.add runHost(hosts[k], s.delayMs, get, results)
    waitFor all(futs)
    i += s.hosts
    stderr.writeLine "  hosts done: ", min(i, hosts.len), "/", hosts.len
  results[]

proc stepFpb(s: Settings): int =
  if s.commit.len != 40:
    stderr.writeLine "catalog_fetch fpb: --commit must be a full 40-character SHA"
    return 2
  let tarball = s.raw / "fpb-" & s.commit & ".tar.gz"
  let url = "https://codeload.github.com/" & FpbRepo & "/tar.gz/" & s.commit
  let (code, _, body) = waitFor follow(url, HttpGet)
  if code != 200:
    stderr.writeLine "catalog_fetch fpb: ", url, " → ", code, " ", body[0 ..< min(body.len, 200)]
    return 1
  writeFile(tarball, body)
  removeDir(s.raw / "fpb")
  createDir(s.raw / "fpb")
  let (output, rc) = execCmdEx("tar xzf " & quoteShell(tarball) & " -C " &
    quoteShell(s.raw / "fpb") & " --strip-components=1")
  if rc != 0:
    stderr.writeLine "catalog_fetch fpb: tar failed: ", output
    return 1
  var m = loadManifest(s.raw)
  m.fpbCommit = s.commit
  m.fetchedAt = nowStamp()
  saveManifest(s.raw, m)
  echo "catalog_fetch fpb: ", s.commit, " → ", s.raw / "fpb"
  0

proc stepHillside(s: Settings): int =
  createDir(s.raw / "hillside")
  for f in walkFiles(s.raw / "hillside" / "*.html"): removeFile(f)
  var start = 0
  var linkIds: seq[int]
  while start >= 0:
    let (code, _, body) = waitFor follow(catalogPageUrl(start), HttpGet)
    if code != 200:
      stderr.writeLine "catalog_fetch hillside: catalog page start=", start, " → ", code
      return 1
    writeFile(s.raw / "hillside" / ("catalog-" & align($start, 4, '0') & ".html"), body)
    let page = parseCatalogPage(body)
    for l in page.links: linkIds.add l.linkId
    if page.nextStart <= start: break
    start = page.nextStart
    sleep(s.delayMs)
  for cat in BookCategories:
    sleep(s.delayMs)
    let (code, _, body) = waitFor follow(bookCategoryUrl(cat), HttpGet)
    if code != 200:
      stderr.writeLine "catalog_fetch hillside: books ", cat, " → ", code
      return 1
    writeFile(s.raw / "hillside" / ("books-" & cat & ".html"), body)
  var m = loadManifest(s.raw)
  for linkId in linkIds:
    sleep(s.delayMs)
    let (code, location, _) = waitFor fetchOnce(weblinkUrl(linkId), HttpHead)
    if code in 300 .. 399 and location.len > 0:
      m.weblinks[linkId] = location
    else:
      stderr.writeLine "catalog_fetch hillside: weblink ", linkId, " → ", code, " (kept as the hillside URL)"
  saveManifest(s.raw, m)
  echo "catalog_fetch hillside: ", linkIds.len, " web links, ", BookCategories.len, " book categories"
  0

proc currentCatalog(s: Settings): BuildOutput =
  assemble(readInputs(s.raw, ""))

proc stepExpand(s: Settings): int =
  let cat = currentCatalog(s)
  var jobs: seq[Job]
  var bases = initTable[string, (string, bool)]()
  for src in cat.sources:
    if not expandable(src): continue
    let readme = if src.url.startsWith("https://github.com/"): githubReadmeUrl(src.url) else: ""
    let url = if readme.len > 0: readme else: src.url
    jobs.add Job(key: $src.id, url: url)
    bases[$src.id] = (src.url, readme.len > 0)
  let results = runAll(jobs, s, get = true)
  createDir(s.raw / "expand")
  var m = loadManifest(s.raw)
  m.expansions.setLen(0)
  var failed = 0
  for j in jobs:
    let (code, final, body) = results.getOrDefault(j.key, (0, "", "not run"))
    let (base, md) = bases.getOrDefault(j.key)
    if code in 200 .. 299:
      let file = "expand" / (j.key & (if md: ".md" else: ".html"))
      writeFile(s.raw / file, body)
      m.expansions.add (j.key, (if md: base else: final), md, file)
    else:
      inc failed
      m.reach[j.key] = classifyReach(max(code, 0), j.url, final)
      if code == -1: m.reach[j.key] = Reachability(status: rRefused)
      m.expansions.add (j.key, base, md, "")
  saveManifest(s.raw, m)
  echo "catalog_fetch expand: ", jobs.len, " lists, ", failed, " could not be fetched"
  0

proc stepReach(s: Settings): int =
  let cat = currentCatalog(s)
  let m0 = loadManifest(s.raw)
  var jobs: seq[Job]
  var seen = initHashSet[string]()
  for src in cat.sources:
    let id = $src.id
    if cat.relevance.getOrDefault(id) != core or id in seen: continue
    var depth1 = false
    for l in src.listings:
      if l.depth == 1: depth1 = true
    if not depth1: continue
    if m0.reach.getOrDefault(id).status != rUnchecked: continue
    seen.incl id
    jobs.add Job(key: id, url: src.url)
  stderr.writeLine "catalog_fetch reach: ", jobs.len, " core sources to check"
  let results = runAll(jobs, s, get = false)
  var m = loadManifest(s.raw)
  for j in jobs:
    let (code, final, _) = results.getOrDefault(j.key, (0, "", "not run"))
    m.reach[j.key] = if code == -1: Reachability(status: rRefused)
                     else: classifyReach(code, j.url, final)
  saveManifest(s.raw, m)
  echo "catalog_fetch reach: ", jobs.len, " checked"
  0

proc main(): int =
  var s = Settings(raw: defaultRaw(), hosts: 8, delayMs: 1000)
  var step = ""
  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      if step.len > 0:
        stderr.writeLine "catalog_fetch: one step at a time"
        return 2
      step = key
    of cmdLongOption, cmdShortOption:
      case key
      of "raw": s.raw = val
      of "commit": s.commit = val
      of "hosts": s.hosts = max(1, parseInt(val))
      of "delay": s.delayMs = max(0, parseInt(val))
      else:
        stderr.writeLine "catalog_fetch: unknown option --" & key
        return 2
    of cmdEnd: discard # getopt never yields cmdEnd inside the loop
  createDir(s.raw)
  case step
  of "fpb": stepFpb(s)
  of "hillside": stepHillside(s)
  of "expand": stepExpand(s)
  of "reach": stepReach(s)
  else:
    stderr.writeLine "usage: catalog_fetch fpb|hillside|expand|reach [--raw:<dir>] [--commit:<sha>]"
    2

when isMainModule:
  quit main()
