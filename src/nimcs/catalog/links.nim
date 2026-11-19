## Links in a fetched page, for the hillside pages and for depth-2 lists (NCK-CAT-03, NCK-CAT-04).
## A scanner, not an HTML parser: it reads `<a ... href="...">text</a>` and Markdown `[text](url)`,
## which is all the catalog needs, and it never runs anything from the page.

import std/[strutils, uri]

type Anchor* = object
  href*: string ## absolute when a base was given and the href was relative
  text*: string ## tags removed, entities decoded, whitespace collapsed

func decodeEntities*(s: string): string {.raises: [].} =
  result = s.multiReplace(("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""),
    ("&#39;", "'"), ("&#039;", "'"), ("&#160;", " "), ("&nbsp;", " "))

func collapse(s: string): string {.raises: [].} =
  var prevSpace = true
  for c in s:
    if c in Whitespace:
      if not prevSpace: result.add ' '
      prevSpace = true
    else:
      result.add c
      prevSpace = false
  result = result.strip

func stripTags(s: string): string {.raises: [].} =
  var inside = false
  for c in s:
    if c == '<': inside = true
    elif c == '>': inside = false
    elif not inside: result.add c

func absolute*(base, href: string): string {.raises: [].} =
  ## `href` resolved against `base`; `href` unchanged when it is absolute or base is empty.
  if base.len == 0 or href.startsWith("http://") or href.startsWith("https://"):
    return href
  try:
    result = $combine(parseUri(base), parseUri(href))
  except UriParseError:
    result = href

func attrValue(tag, name: string): string {.raises: [].} =
  ## The value of attribute `name` in the opening tag text `tag` (quoted with " or ').
  let low = tag.toLowerAscii
  var i = 0
  while true:
    i = low.find(name & "=", i)
    if i < 0: return ""
    if i == 0 or low[i - 1] in Whitespace: break
    i += name.len
  var j = i + name.len + 1
  if j >= tag.len: return ""
  let q = tag[j]
  if q in {'"', '\''}:
    let k = tag.find(q, j + 1)
    if k < 0: return ""
    return tag[j + 1 ..< k]
  var k = j
  while k < tag.len and tag[k] notin Whitespace and tag[k] != '>': inc k
  tag[j ..< k]

func htmlAnchors*(html, base: string): seq[Anchor] {.raises: [].} =
  let low = html.toLowerAscii
  var i = 0
  while true:
    i = low.find("<a", i)
    if i < 0: break
    if i + 2 < low.len and low[i + 2] notin Whitespace:
      i += 2
      continue
    let close = low.find('>', i)
    if close < 0: break
    let endTag = low.find("</a", close)
    if endTag < 0: break
    let href = decodeEntities(attrValue(html[i .. close], "href")).strip
    let text = collapse(decodeEntities(stripTags(html[close + 1 ..< endTag])))
    if href.len > 0:
      result.add Anchor(href: absolute(base, href), text: text)
    i = endTag + 3

func markdownAnchors*(md, base: string): seq[Anchor] {.raises: [].} =
  var i = 0
  while true:
    let open = md.find('[', i)
    if open < 0: break
    let close = md.find("](", open)
    if close < 0: break
    let nl = md.find('\n', open)
    if nl >= 0 and nl < close:
      i = open + 1
      continue
    let stop = md.find(')', close + 2)
    if stop < 0: break
    let text = md[open + 1 ..< close].strip
    let href = md[close + 2 ..< stop].strip.split(' ')[0]
    if href.len > 0:
      result.add Anchor(href: absolute(base, href), text: text)
    i = stop + 1

func isWebLink*(href: string): bool {.raises: [].} =
  href.startsWith("http://") or href.startsWith("https://")
