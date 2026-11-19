## E tests for docs/specification.md NCK-CAT-01…NCK-CAT-07 (the catalog).

import std/[json, os, strutils, tables, unittest]
import propcheck
import nimcs/catalog/[build, fpb, hillside, model, triage]

const root = currentSourcePath().parentDir.parentDir

suite "NCK-C catalog":
  # SPEC: NCK-CAT-01
  test "NCK-CAT-01 Given a list line with authors, formats, licence and archive mark, when parsed, then every field is read":
    let line = "* [Purely Functional Things](https://example.org/pf.pdf) - A. Author, B. Author (PDF, EPUB) *( :card_file_box: archived)* (CC BY-SA)"
    let (ok, s) = parseEntry(line)
    check ok
    check s.title == "Purely Functional Things"
    check s.url == "https://example.org/pf.pdf"
    check s.authors == "A. Author, B. Author"
    check s.formats == @["PDF", "EPUB"]
    check s.licenses == @["CC BY-SA"]
    check s.archived

  # SPEC: NCK-CAT-01
  test "NCK-CAT-01 Given a list file, when parsed, then entries carry the heading path and language, and index links are not entries":
    let text = "## BY SUBJECT\n\n### Index\n\n* [Algorithms](#algorithms)\n\n### Algorithms\n\n" &
      "* [Book \\[2nd\\]](https://a.example/b_(x)) - Someone\n#### Graphs\n* [G](http://g.example)\n"
    let xs = parseList("books/free-programming-books-ja.md", text)
    check xs.len == 2
    check xs[0].title == "Book [2nd]"
    check xs[0].url == "https://a.example/b_(x)"
    check xs[0].lang == "ja"
    check xs[0].listings[0].section == @["BY SUBJECT", "Algorithms"]
    check xs[1].listings[0].section == @["BY SUBJECT", "Algorithms", "Graphs"]
    check langOfFile("free-programming-books-subjects.md") == "en"
    check langOfFile("free-courses-pt_BR.md") == "pt_BR"

  # SPEC: NCK-CAT-02
  test "NCK-CAT-02 Given URLs differing only in case of host, fragment or trailing slash, when identified, then they share one id":
    check sourceIdOf("https://Example.org/a/") == sourceIdOf("https://example.org/a#top")
    check sourceIdOf("http://example.org/a") != sourceIdOf("https://example.org/a")
    check ($sourceIdOf("https://example.org")).len == 16

  # SPEC: NCK-CAT-02
  test "NCK-CAT-02 Given any URL, when normalized twice, then the result equals normalizing once":
    let gen = stringOf("abcXYZ/#.:?=", 0, 20).map(proc(s: string): string = "https://Host.Example/" & s)
    let outcome = check(gen, proc(u: string): bool {.raises: [CatchableError].} =
      normalizeUrl(normalizeUrl(u)) == normalizeUrl(u))
    checkpoint describe(outcome)
    check outcome.passed

  # SPEC: NCK-CAT-02
  test "NCK-CAT-02 Given two listings of one URL, when merged in either order, then the result is the same and keeps both":
    let a = parseList("books/x-en.md", "### A\n* [T1](https://e.org/x)\n")[0]
    let b = parseList("courses/y-en.md", "### B\n* [T2](https://e.org/x/) (PDF)\n")[0]
    let ab = dedupe([a, b])
    let ba = dedupe([b, a])
    check ab.len == 1
    check ab == ba
    check ab[0].listings.len == 2
    check ab[0].title == "T1" # from the earlier listing, books/ before courses/
    check ab[0].formats == @["PDF"]
    check dedupe(ab) == ab

  # SPEC: NCK-CAT-03
  test "NCK-CAT-03 Given a catalog page, when parsed, then web links and the next page are found":
    let html = """<li><a href="/patterns/patterns-catalog?task=weblink.go&amp;id=7" class="category">Portland Pattern Repository</a></li>
      <li><a href="/patterns/patterns-catalog?task=weblink.go&amp;id=12">System Reengineering Patterns</a></li>
      <a href="/patterns/patterns-catalog?start=20">Next</a>"""
    let page = parseCatalogPage(html)
    check page.links.len == 2
    check page.links[0] == WebLink(linkId: 7, title: "Portland Pattern Repository")
    check page.nextStart == 20
    check parseCatalogPage("<p>last page</p>").nextStart == -1

  # SPEC: NCK-CAT-03
  test "NCK-CAT-03 Given a redirect target for a web link, when assembled, then the source has the target URL; a book category yields book pages":
    var inputs = BuildInputs(fpbCommit: "x", fetchedAt: "t")
    inputs.catalogPages = @["""<a href="/patterns/patterns-catalog?task=weblink.go&amp;id=7">PPR</a>"""]
    inputs.weblinkTargets[7] = "http://c2.com/ppr/index.html"
    inputs.bookPages = @[("design-patterns", """<td class="list-title"><a href="/patterns/books/design-patterns/277-service-design-patterns"> Service Design Patterns </a></td>""")]
    let o = assemble(inputs)
    check o.sources.len == 2
    var urls: seq[string]
    for s in o.sources: urls.add s.url
    check "http://c2.com/ppr/index.html" in urls
    check "https://hillside.net/patterns/books/design-patterns/277-service-design-patterns" in urls

  # SPEC: NCK-CAT-04
  test "NCK-CAT-04 Given meta-lists on GitHub and elsewhere, when checked, then only the GitHub one is followed and the other has a reason":
    let xs = parseList("books/free-programming-books-subjects.md",
      "### 0 - Meta-Lists\n* [L](https://github.com/o/r)\n* [S](https://www.site.example)\n### Algorithms\n* [B](https://github.com/o/b)\n")
    check expandable(xs[0])
    check not expandable(xs[1])
    check notFollowedReason(xs[1]).len > 0
    check not expandable(xs[2])
    check githubReadmeUrl("https://github.com/o/r") == "https://raw.githubusercontent.com/o/r/HEAD/README.md"

  # SPEC: NCK-CAT-04
  test "NCK-CAT-04 Given an expanded list, when assembled, then its links are depth-2 listings naming the list, capped per list":
    var inputs = BuildInputs(fpbCommit: "x", fetchedAt: "t")
    inputs.fpbFiles = @[("books/free-programming-books-subjects.md", "### 0 - Meta-Lists\n* [Pattern List](https://github.com/o/r)\n")]
    let listId = $sourceIdOf("https://github.com/o/r")
    var md = ""
    for i in 0 ..< MaxLinksPerExpansion + 10: md.add "* [Pattern " & $i & "](https://p.example/" & $i & ")\n"
    inputs.expansions = @[Expansion(listId: listId, base: "https://github.com/o/r", markdown: true, body: md)]
    let o = assemble(inputs)
    check o.sources.len == 1 + MaxLinksPerExpansion
    var depth2 = 0
    for s in o.sources:
      for l in s.listings:
        if l.depth == 2:
          inc depth2
          check l.via == listId
    check depth2 == MaxLinksPerExpansion

  # SPEC: NCK-CAT-05
  test "NCK-CAT-05 Given headings and titles, when classified, then keywords decide and short keywords match whole words only":
    let core1 = parseList("books/x-en.md", "### Algorithms & Data Structures\n* [Q](https://q.example)\n")[0]
    let nimS = parseList("books/x-en.md", "### Nim\n* [N](https://n.example)\n")[0]
    let anim = parseList("books/x-en.md", "### Animation\n* [A](https://a.example)\n")[0]
    let clean = parseList("books/x-en.md", "### Clean Code\n* [C](https://c.example)\n")[0]
    let ja = parseList("books/x-ja.md", "### アルゴリズム\n* [J](https://j.example)\n")[0]
    let screencast = parseList("casts/free-podcasts-screencasts-en.md", "### Algorithms\n* [P](https://p.example)\n")[0]
    check classify(core1) == core
    check classify(nimS) == core
    check classify(anim) == adjacent
    check classify(clean) == adjacent
    check classify(ja) == core
    check classify(screencast) == outOfScope

  # SPEC: NCK-CAT-05
  test "NCK-CAT-05 Given an override, when assembled, then the hand decision wins":
    var inputs = BuildInputs(fpbCommit: "x", fetchedAt: "t")
    inputs.fpbFiles = @[("books/x-en.md", "### Animation\n* [A](https://a.example)\n")]
    let id = $sourceIdOf("https://a.example")
    check assemble(inputs).relevance[id] == adjacent
    inputs.overrides[id] = core
    check assemble(inputs).relevance[id] == core

  # SPEC: NCK-CAT-06
  test "NCK-CAT-06 Given the same inputs in another order, when assembled twice, then the bytes are identical and every line is valid JSON":
    var a = BuildInputs(fpbCommit: "x", fetchedAt: "t")
    a.fpbFiles = @[("books/a-en.md", "### Algorithms\n* [A](https://a.example) (PDF)\n* [B](https://b.example)\n"),
                   ("courses/b-en.md", "### Haskell\n* [A again](https://a.example/)\n* [Bad \xFF title](https://c.example)\n")]
    var b = a
    b.fpbFiles = @[a.fpbFiles[1], a.fpbFiles[0]]
    let oa = assemble(a)
    let ob = assemble(b)
    check oa.sourcesJsonl == ob.sourcesJsonl
    check oa.metaJson == ob.metaJson
    check oa.triageJson == ob.triageJson
    check assemble(a).sourcesJsonl == oa.sourcesJsonl
    for line in oa.sourcesJsonl.strip.splitLines:
      check validUtf8(line) == line
      check parseJson(line).hasKey("id")

  # SPEC: NCK-CAT-06
  test "NCK-CAT-06 Given the committed catalog, when rebuilt from raw/, then it is unchanged (skipped without raw/)":
    let raw = getEnv("NIMCS_RAW", getHomeDir() / ".cache" / "nim-cs-knowledge" / "raw")
    if not fileExists(raw / "manifest.json"):
      skip()
    else:
      let tmp = getTempDir() / "nck-catalog-rebuild"
      removeDir(tmp)
      createDir(tmp)
      if fileExists(root / "catalog" / "overrides.json"):
        copyFile(root / "catalog" / "overrides.json", tmp / "overrides.json")
      let rc = execShellCmd(quoteShell(root / "bin" / "catalog_build") & " --out:" & quoteShell(tmp) & " > /dev/null")
      check rc == 0
      for f in ["meta.json", "sources.jsonl", "triage.json"]:
        check readFile(tmp / f) == readFile(root / "catalog" / f)

  # SPEC: NCK-CAT-07
  test "NCK-CAT-07 Given every module under src/, when its imports are read, then none is a networking module":
    for f in walkDirRec(root / "src"):
      if not f.endsWith(".nim"): continue
      for line in readFile(f).splitLines:
        let t = line.strip
        if t.startsWith("import ") or t.startsWith("from "):
          for banned in ["httpclient", "asynchttpserver", "net", "asyncnet", "nativesockets"]:
            check banned notin t.multiReplace(("[", " "), ("]", " "), (",", " ")).splitWhitespace
