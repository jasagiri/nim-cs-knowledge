## Reading free-programming-books' Markdown lists: every `* [title](url) - authors (notes)` line
## under its heading path (NCK-CAT-01).

import std/[strutils]
import ./model

const
  KnownFormats = ["ASCIIDOC", "CHM", "DJVU", "DOC", "DOCX", "EPUB", "GITBOOK", "HTML", "IPYNB",
    "JUPYTER", "KINDLE", "LATEX", "MARKDOWN", "MD", "MOBI", "ODT", "ONLINE", "PDF", "PPT",
    "POSTSCRIPT", "PS", "RST", "TEX", "TXT", "VIDEO", "XML", "ZIP", "AZW3", "IBOOKS", "WEB"]
  LicenseMarks = ["CC", "GFDL", "GPL", "MIT", "APACHE", "BSD", "PUBLIC DOMAIN", "OPL", "OPEN",
    "UNLICENSE", "MPL", "LGPL"]

func langOfFile*(name: string): string {.raises: [].} =
  ## `free-programming-books-ja.md` → "ja"; the English lists (`-langs`, `-subjects`, and files
  ## with no language part) → "en".
  var stem = name
  if stem.endsWith(".md"): stem.setLen(stem.len - 3)
  let dash = stem.rfind('-')
  if dash < 0: return "en"
  let tail = stem[dash + 1 .. ^1]
  let base = if '_' in tail: tail.split('_')[0] else: tail
  if base.len in 2..3 and base.allCharsInSet({'a'..'z'}) and tail notin ["langs", "cp"]:
    tail
  else:
    "en"

func heading(line: string): (int, string) {.raises: [].} =
  ## The level and text of a Markdown heading, or (0, "") when the line is not one.
  var level = 0
  while level < line.len and line[level] == '#': inc level
  if level == 0 or level > 6 or level >= line.len or line[level] != ' ':
    return (0, "")
  (level, line[level + 1 .. ^1].strip)

func linkAt(line: string; start: int): (string, string, int) {.raises: [].} =
  ## The `[text](url)` starting at `start` (which must be '['): text, url and the index after ')'.
  ## Brackets in the text and parentheses in the url may nest; `\]` is an escaped bracket.
  ## Returns an empty url when the line has no complete link there.
  var depth = 0
  var i = start
  while i < line.len:
    let c = line[i]
    if c == '\\' and i + 1 < line.len:
      i += 2
      continue
    if c == '[': inc depth
    elif c == ']':
      dec depth
      if depth == 0: break
    inc i
  if i >= line.len - 1 or line[i + 1] != '(':
    return ("", "", start)
  let text = line[start + 1 ..< i].replace("\\", "")
  var j = i + 2
  var paren = 1
  while j < line.len:
    if line[j] == '(': inc paren
    elif line[j] == ')':
      dec paren
      if paren == 0: break
    inc j
  if j >= line.len:
    return ("", "", start)
  (text, line[i + 2 ..< j].strip, j + 1)

func parenGroups(s: string): seq[string] {.raises: [].} =
  ## The top-level parenthesized groups of `s`, without the parentheses.
  var depth = 0
  var cur = ""
  for c in s:
    if c == '(':
      if depth > 0: cur.add c
      inc depth
    elif c == ')' and depth > 0:
      dec depth
      if depth == 0:
        result.add cur.strip
        cur = ""
      else: cur.add c
    elif depth > 0:
      cur.add c

func isFormatGroup(g: string): bool {.raises: [].} =
  let parts = g.split({',', '/'})
  result = parts.len > 0
  for p in parts:
    if p.strip.toUpperAscii notin KnownFormats: return false

func isLicenseGroup(g: string): bool {.raises: [].} =
  let up = g.toUpperAscii
  for m in LicenseMarks:
    if up.startsWith(m): return true

func parseEntry*(line: string): (bool, Source) {.raises: [].} =
  ## One list line. (false, …) when the line is not an entry.
  let t = line.strip
  if t.len < 4 or t[0] notin {'*', '-'} or t[1] != ' ' or t[2] != '[':
    return (false, Source())
  let (title, url, after) = linkAt(t, 2)
  if url.len == 0 or not (url.startsWith("http://") or url.startsWith("https://")):
    return (false, Source())
  var rest = t[after .. ^1].strip
  var src = Source(url: url, title: title.strip, id: sourceIdOf(url))
  if rest.startsWith("- ") or rest.startsWith("– "):
    rest = rest[2 .. ^1]
  let open = rest.find('(')
  src.authors = (if open >= 0: rest[0 ..< open] else: rest).strip(chars = {' ', '*', '-'})
  for g in parenGroups(rest):
    if "archived" in g.toLowerAscii:
      src.archived = true
    elif isFormatGroup(g):
      for p in g.split({',', '/'}):
        let f = p.strip.toUpperAscii
        if f notin src.formats: src.formats.add f
    elif isLicenseGroup(g):
      if g notin src.licenses: src.licenses.add g
  (true, src)

func parseList*(file, text: string): seq[Source] {.raises: [].} =
  ## Every entry of one list file, each with one depth-1 listing carrying its heading path.
  let lang = langOfFile(file)
  var path: seq[string]
  for line in text.splitLines:
    let (level, name) = heading(line)
    if level > 0:
      if path.len >= level: path.setLen(level - 1)
      while path.len < level - 1: path.add ""
      path.add name
      continue
    let (ok, src) = parseEntry(line)
    if not ok: continue
    var s = src
    s.lang = lang
    var section: seq[string]
    for p in path:
      if p.len > 0: section.add p
    s.listings = @[Listing(origin: oFpb, file: file, section: section, depth: 1)]
    result.add s
