import std/[unittest, strutils]
import propcheck
import nimcs/fp/result
import nimcs/patterns/factory_method

func repeat101(): string {.raises: [].} =
  for i in 0 ..< 101: result.add('a')

func mkDoc(title: string; paras: seq[string]): Doc {.raises: [].} =
  Doc(title: title, paras: paras)

func docs(): Gen[Doc] {.raises: [ValueError].} =
  pair(stringOf("abc xyz", 1, 8), seqOf(stringOf("abc ", 0, 6), 0, 4)).map(
    proc(p: (string, seq[string])): Doc {.raises: [].} = mkDoc(p[0], p[1]))

func formats(): Gen[Format] {.raises: [ValueError].} =
  pick([fmtText, fmtMarkdown, fmtHtml])

# SPEC: GOF-FACTORYMETHOD-01
test "GOF-FACTORYMETHOD-01 Given any document and format, when published with the standard factory, then name and body come from the exporter":
  let outcome = check(pair(docs(), formats()), proc(p: (Doc, Format)): bool {.raises: [CatchableError].} =
    let made = standardFactory(p[1])
    let pub = publish(p[0], standardFactory, p[1])
    made.isOk and pub.isOk and
      pub.value.name == p[0].title & "." & made.value.ext and
      pub.value.body == made.value.render(p[0]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-FACTORYMETHOD-01
test "GOF-FACTORYMETHOD-01 Given a document, when published as markdown, then the body is the known markdown text":
  let r = publish(mkDoc("T", @["a"]), standardFactory, fmtMarkdown)
  check r.isOk
  check r.value.name == "T.md"
  check r.value.body == "# T\n\na\n"

# SPEC: GOF-FACTORYMETHOD-02
test "GOF-FACTORYMETHOD-02 Given a factory that refuses a format, when published, then the factory's error comes back":
  let outcome = check(pair(docs(), pick([fmtMarkdown, fmtHtml])), proc(p: (Doc, Format)): bool {.raises: [CatchableError].} =
    let pub = publish(p[0], textOnlyFactory, p[1])
    pub.isErr and pub.error == textOnlyFactory(p[1]).error)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-FACTORYMETHOD-03
test "GOF-FACTORYMETHOD-03 Given the same document, when published with another factory, then the product differs and publish is unchanged":
  let d = mkDoc("T", @["a"])
  let viaStandard = publish(d, standardFactory, fmtText)
  let viaText = publish(d, textOnlyFactory, fmtText)
  check viaStandard == viaText # the second factory delegates for text
  let md = publish(d, standardFactory, fmtMarkdown)
  let html = publish(d, standardFactory, fmtHtml)
  check md.isOk and html.isOk
  check md.value.name != html.value.name
  check md.value.body != html.value.body
  let custom: ExporterFactory = proc(f: Format): Result[Exporter, string] {.noSideEffect, raises: [].} =
    ok(Exporter(ext: "up", render: proc(x: Doc): string {.noSideEffect, raises: [].} = x.title), string)
  let c = publish(d, custom, fmtHtml)
  check c.isOk
  check c.value.name == "T.up"
  check c.value.body == "T"

func countOf(s: string; c: char): int {.raises: [].} =
  for ch in s:
    if ch == c: result += 1

func entitiesOk(body: string): bool {.raises: [].} =
  ## Every '&' starts one of the entities the renderer is allowed to write.
  for i in 0 ..< body.len:
    if body[i] == '&':
      let rest = body[i .. ^1]
      var good = false
      for e in ["&amp;", "&lt;", "&gt;", "&quot;", "&#39;"]:
        if rest.len >= e.len and rest[0 ..< e.len] == e: good = true
      if not good: return false
  true

# SPEC: GOF-FACTORYMETHOD-04
test "GOF-FACTORYMETHOD-04 Given text with markup characters, when published as html, then only the renderer's own tags are markup":
  let outcome = check(pair(stringOf("a<>&\"' ", 1, 6), seqOf(stringOf("a<>&\"'", 0, 6), 0, 4)),
    proc(p: (string, seq[string])): bool {.raises: [CatchableError].} =
      let pub = publish(mkDoc(p[0], p[1]), standardFactory, fmtHtml)
      let tags = 1 + p[1].len
      pub.isOk and countOf(pub.value.body, '<') == 2 * tags and
        countOf(pub.value.body, '>') == 2 * tags and entitiesOk(pub.value.body))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-FACTORYMETHOD-04
test "GOF-FACTORYMETHOD-04 Given a script tag in a paragraph, when published as html, then it is escaped":
  let r = publish(mkDoc("T", @["<script>x()</script> & \"q\" 'z'"]), standardFactory, fmtHtml)
  check r.value.body == "<h1>T</h1><p>&lt;script&gt;x()&lt;/script&gt; &amp; &quot;q&quot; &#39;z&#39;</p>"

# SPEC: GOF-FACTORYMETHOD-05
test "GOF-FACTORYMETHOD-05 Given an unsafe title, when published, then it is refused for every format":
  for bad in ["", "..", "a/b", "a\\b", "x..y", ".hidden", "x.", "a:b", "a\0b", "a\nb", repeat101()]:
    for f in [fmtText, fmtMarkdown, fmtHtml]:
      let r = publish(mkDoc(bad, @[]), standardFactory, f)
      check r.isErr
      check r.error == "invalid title"

# SPEC: GOF-FACTORYMETHOD-05
test "GOF-FACTORYMETHOD-05 Given any title from a hostile alphabet, when publishing succeeds, then the name has no path or control characters":
  let outcome = check(stringOf("ab ./\\:\n", 0, 8), proc(t: string): bool {.raises: [CatchableError].} =
    let r = publish(mkDoc(t, @[]), standardFactory, fmtText)
    if r.isErr: r.error == "invalid title"
    else:
      var clean = true
      for c in r.value.name:
        if c in {'/', '\\', ':'} or c < ' ': clean = false
      clean and ".." notin r.value.name and r.value.name.len > 0)
  checkpoint describe(outcome)
  check outcome.passed
