## Reading the Hillside Group's pattern pages (NCK-CAT-03): the Patterns Catalog (a paged list of
## web links that hillside redirects to their targets) and the Books categories (lists of book pages).

import std/[strutils]
import ./links

const
  HillsideBase* = "https://hillside.net"
  CatalogPath* = "/patterns/patterns-catalog"
  BookCategories* = ["business-process-patterns", "coding-patterns-idioms-style",
    "design-patterns", "organizational-patterns", "other-patterns", "other-process-patterns",
    "technology-language-specific-design-patterns", "architecture-and-requirements-patterns"]

type
  WebLink* = object
    linkId*: int ## hillside's weblink id; its target is the redirect of weblink.go&id=<linkId>
    title*: string

  CatalogPage* = object
    links*: seq[WebLink]
    nextStart*: int ## the `start=` of the next page, or -1 on the last page

func catalogPageUrl*(start: int): string {.raises: [].} =
  HillsideBase & CatalogPath & (if start == 0: "" else: "?start=" & $start)

func weblinkUrl*(linkId: int): string {.raises: [].} =
  HillsideBase & CatalogPath & "?task=weblink.go&id=" & $linkId

func bookCategoryUrl*(category: string): string {.raises: [].} =
  HillsideBase & "/patterns/books/" & category & "?limit=0"

func digitsAt(s: string; start: int): int {.raises: [].} =
  ## The decimal number at `start` (at most 9 digits, so it cannot overflow), or -1 when none.
  result = -1
  var i = start
  while i < s.len and i - start < 9 and s[i] in Digits:
    result = (if result < 0: 0 else: result * 10) + (ord(s[i]) - ord('0'))
    inc i

func parseCatalogPage*(html: string): CatalogPage {.raises: [].} =
  result.nextStart = -1
  for a in htmlAnchors(html, HillsideBase):
    let marker = "task=weblink.go&id="
    let at = a.href.find(marker)
    if at >= 0:
      let linkId = digitsAt(a.href, at + marker.len)
      if linkId >= 0:
        result.links.add WebLink(linkId: linkId, title: a.text)
    elif a.text == "Next":
      let s = a.href.find("start=")
      if s >= 0:
        result.nextStart = digitsAt(a.href, s + 6)

func parseBookCategory*(html, category: string): seq[Anchor] {.raises: [].} =
  ## The book pages a category lists: links under /patterns/books/<category>/<id>-<slug>.
  let prefix = HillsideBase & "/patterns/books/" & category & "/"
  for a in htmlAnchors(html, HillsideBase):
    if a.href.startsWith(prefix) and a.text.len > 0:
      var seen = false
      for r in result:
        if r.href == a.href: seen = true
      if not seen: result.add a
