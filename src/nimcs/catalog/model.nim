## The catalog's data: one `Source` per distinct URL, with every place a list mentions it.
## Everything here is pure; reading and writing files is the tools' job (tools/).

import std/[algorithm, strutils, unicode, uri]

type
  SourceId* = distinct string ## 16 hex digits of FNV-1a 64 over the normalized URL (NCK-CAT-02)

  Origin* = enum
    oFpb = "free-programming-books"
    oHillside = "hillside"

  Listing* = object
    ## One mention of a URL in a list: the file (or page) and the heading path above it.
    origin*: Origin
    file*: string
    section*: seq[string]
    depth*: int ## 1: listed by a start point; 2: listed by a depth-1 list (NCK-CAT-04)
    via*: string ## for depth 2, the id of the depth-1 list; empty otherwise

  Reach* = enum
    rUnchecked = "unchecked"
    rOk = "ok"
    rRedirected = "redirected"
    rDead = "dead"
    rRefused = "refused" ## robots.txt or the server said no (401/403/429)
    rError = "error" ## DNS, TLS, timeout

  Source* = object
    id*: SourceId
    url*: string
    title*: string
    authors*: string
    formats*: seq[string]
    licenses*: seq[string] ## as the list states them; empty when the list states none
    archived*: bool
    lang*: string
    listings*: seq[Listing]

func `==`*(a, b: SourceId): bool {.borrow.}
func `<`*(a, b: SourceId): bool {.borrow.}
func `$`*(a: SourceId): string {.borrow.}

func normalizeUrl*(raw: string): string {.raises: [].} =
  ## Lower-case scheme and host, no fragment, no trailing slash on the path, http and https kept
  ## apart (they can be different servers). Idempotent: normalizeUrl(normalizeUrl(u)) == normalizeUrl(u).
  let s = raw.strip
  var u: Uri
  try:
    u = parseUri(s)
  except UriParseError:
    return s
  if u.scheme.len == 0 or u.hostname.len == 0:
    return s
  u.scheme = u.scheme.toLowerAscii
  u.hostname = u.hostname.toLowerAscii
  u.anchor = ""
  # Every trailing slash, not one: removing one at a time would make "a///" normalize to "a//",
  # then "a/" on the next call (the property test of NCK-CAT-02 found this).
  while u.path.endsWith("/"):
    u.path.setLen(u.path.len - 1)
  result = $u

func validUtf8*(s: string): string {.raises: [].} =
  ## `s` with every byte that does not start a valid UTF-8 sequence replaced by U+FFFD. Pages in
  ## legacy encodings (Windows-1252 quotes on old pattern pages) would otherwise make the catalog
  ## invalid JSON text; the replacement shows where the original bytes were. Idempotent.
  var i = 0
  while i < s.len:
    let bad = validateUtf8(s[i .. ^1])
    if bad < 0:
      result.add s[i .. ^1]
      break
    result.add s[i ..< i + bad]
    result.add "\u{FFFD}"
    i += bad + 1

func fnv1a64(s: string): uint64 {.raises: [].} =
  result = 0xcbf29ce484222325'u64
  for c in s:
    result = (result xor uint64(ord(c))) * 0x100000001b3'u64

func sourceIdOf*(url: string): SourceId {.raises: [].} =
  SourceId(toHex(fnv1a64(normalizeUrl(url)), 16).toLowerAscii)

func cmpListing(a, b: Listing): int {.raises: [].} =
  result = cmp(a.depth, b.depth)
  if result == 0: result = cmp(ord(a.origin), ord(b.origin))
  if result == 0: result = cmp(a.file, b.file)
  if result == 0: result = cmp(a.section.join("\x1f"), b.section.join("\x1f"))
  if result == 0: result = cmp(a.via, b.via)

func union(a, b: seq[string]): seq[string] {.raises: [].} =
  result = a
  for x in b:
    if x notin result: result.add x
  result.sort()

func merge*(a, b: Source): Source {.raises: [].} =
  ## Two mentions of one URL become one source. Commutative and idempotent up to the order of
  ## the listings, which is sorted: merge(a, b) == merge(b, a), merge(a, a) == a with a sorted.
  ## Title, authors and lang come from the earlier listing (by cmpListing), so the result does not
  ## depend on the order the lists were read in.
  let first = if b.listings.len > 0 and (a.listings.len == 0 or
      cmpListing(b.listings[0], a.listings[0]) < 0): b else: a
  result = first
  result.formats = union(a.formats, b.formats)
  result.licenses = union(a.licenses, b.licenses)
  result.archived = a.archived or b.archived
  var ls = a.listings
  for l in b.listings:
    if l notin ls: ls.add l
  ls.sort(cmpListing)
  result.listings = ls

func dedupe*(sources: openArray[Source]): seq[Source] {.raises: [].} =
  ## Merge sources that share an id; the result is sorted by id.
  var sorted = @sources
  for s in sorted.mitems:
    s.listings.sort(cmpListing)
    s.formats.sort()
    s.licenses.sort()
  sorted.sort(proc(a, b: Source): int = cmp(a.id, b.id))
  for s in sorted:
    if result.len > 0 and result[^1].id == s.id:
      result[^1] = merge(result[^1], s)
    else:
      result.add s
