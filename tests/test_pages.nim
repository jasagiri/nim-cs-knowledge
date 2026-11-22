## E tests for docs/specification.md NCK-KNOW-01…NCK-KNOW-06 (details pages, skills, modules) and
## NCK-STYLE-01…NCK-STYLE-02 (style).

import std/[os, osproc, sets, streams, strutils, unittest]
import nimcs/dataset

const
  root = currentSourcePath().parentDir.parentDir
  Sections = ["Intent", "Use when / avoid when", "Nim shape", "Public API", "Laws and invariants", "Complexity",
              "Pitfalls", "Related", "Sources"]
  Areas = ["fp", "ds", "algo", "patterns"]

proc detailsPages(): seq[string] =
  for skill in walkDirs(root / "skills" / "*"):
    for f in walkFiles(skill / "details" / "*.md"): result.add f

proc skillFiles(): seq[string] =
  for skill in walkDirs(root / "skills" / "*"):
    if fileExists(skill / "SKILL.md"): result.add skill / "SKILL.md"

proc catalogIdSet(): HashSet[string] =
  for line in lines(root / "catalog" / "sources.jsonl"):
    let at = line.find("\"id\":\"")
    if at >= 0: result.incl line[at + 6 ..< at + 22]

proc knowledgeModules(): seq[string] =
  for a in Areas:
    for f in walkFiles(root / "src" / "nimcs" / a / "*.nim"): result.add f

proc knowledgeSources(): seq[string] =
  ## Every Nim file under the areas, sub-directories included: a concept may split into files
  ## (patterns/layered_architecture/), and NCK-STYLE-02 holds for all of them.
  for a in Areas:
    for f in walkDirRec(root / "src" / "nimcs" / a):
      if f.endsWith(".nim"): result.add f

suite "NCK-K pages and modules":
  let pages = detailsPages()

  test "Given the skills, when pages are collected, then there are pages to check":
    check pages.len > 0

  # SPEC: NCK-KNOW-01
  test "NCK-KNOW-01 Given every details page, when its headings are read, then the nine sections appear in order with a bad example under Pitfalls":
    for f in pages:
      let p = parsePage(readFile(f))
      var names: seq[string]
      for (h, _) in p.sections: names.add h
      if names != @Sections: checkpoint f.relativePath(root) & ": " & $names
      check names == @Sections
      var bad = false
      for b in p.blocks:
        if b.bad and b.section == "Pitfalls": bad = true
      if not bad: checkpoint f.relativePath(root) & ": no `nim bad` block under Pitfalls"
      check bad

  # SPEC: NCK-KNOW-02
  test "NCK-KNOW-02 Given every nim block of the skills, when compiled alone under the lint settings and run, then it builds and every assertion holds":
    let work = getTempDir() / "nck-examples-" & $getCurrentProcessId()
    var cfg = "--path:\"" & root / "src" & "\"\n"
    for line in readFile(root / "nim.cfg").splitLines:
      if line.startsWith("--") and "--path" notin line: cfg.add line & "\n"
    removeDir(work)
    var places, cmds: seq[string]
    for f in skillFiles() & pages:
      var inside = false
      var good = false
      var code = ""
      var lineNo = 0
      let ls = readFile(f).splitLines()
      for i, line in ls:
        if not inside and line.startsWith("```nim"):
          let info = line[3 .. ^1].strip
          if info notin ["nim", "nim bad"]: checkpoint f & ":" & $(i + 1) & ": fence " & info
          check info in ["nim", "nim bad"]
          inside = true
          good = info == "nim"
          code = ""
          lineNo = i + 1
        elif inside and line.startsWith("```"):
          inside = false
          if good:
            let dir = work / $places.len
            createDir(dir)
            writeFile(dir / "nim.cfg", cfg)
            writeFile(dir / "example.nim", code)
            places.add f.relativePath(root) & ":" & $lineNo
            cmds.add "cd " & quoteShell(dir) & " && nim r --hints:off --nimcache:nc example.nim"
        elif inside:
          code.add line & "\n"
    # Run, not only `nim check`: a doAssert in an example is a claim of the page, and only running
    # it tests the claim.
    var outputs = newSeq[string](cmds.len)
    var codes = newSeq[int](cmds.len)
    discard execProcesses(cmds, options = {poStdErrToStdOut, poUsePath, poEvalCommand},
      afterRunEvent = proc(i: int; p: Process) =
        outputs[i] = p.outputStream.readAll
        codes[i] = p.peekExitCode)
    for i in 0 ..< cmds.len:
      if codes[i] != 0: checkpoint places[i] & "\n" & outputs[i]
      check codes[i] == 0
    removeDir(work)
    check cmds.len > 0

  # SPEC: NCK-KNOW-03
  test "NCK-KNOW-03 Given every Sources section, when read, then it cites existing catalog IDs or says why there are none":
    let known = catalogIdSet()
    for f in pages:
      let body = parsePage(readFile(f)).section("Sources")
      let ids = catalogIds(body)
      let none = "None in the catalog:" in body
      if ids.len == 0 and not none: checkpoint f.relativePath(root) & ": no catalog ID"
      check ids.len > 0 or none
      for id in ids:
        if id notin known: checkpoint f.relativePath(root) & ": unknown catalog ID " & id
        check id in known

  # SPEC: NCK-KNOW-04
  test "NCK-KNOW-04 Given pages and modules, when matched, then every page names an existing module and every module has a page":
    var named = initHashSet[string]()
    for f in pages:
      let text = readFile(f)
      var found = false
      for a in Areas:
        let marker = "src/nimcs/" & a & "/"
        var at = text.find(marker)
        while at >= 0:
          var stop = at + marker.len
          while stop < text.len and text[stop] in IdentChars: inc stop
          if text.continuesWith(".nim", stop) and fileExists(root / text[at ..< stop + 4]):
            found = true
            named.incl text[at ..< stop + 4]
          at = text.find(marker, at + 1)
      if not found: checkpoint f.relativePath(root) & ": names no existing module"
      check found
    for m in knowledgeModules():
      let rel = m.relativePath(root)
      if rel notin named: checkpoint rel & ": no details page names it"
      check rel in named

  # SPEC: NCK-KNOW-05
  test "NCK-KNOW-05 Given every SKILL.md, when read, then it has name and description and links each details page of its skill":
    for f in skillFiles():
      let text = readFile(f)
      check text.startsWith("---\n")
      let fm = text.split("\n---", 1)[0]
      check "\nname: " & f.parentDir.extractFilename in fm
      check "\ndescription:" in fm
      for d in walkFiles(f.parentDir / "details" / "*.md"):
        let link = "details/" & d.extractFilename
        if link notin text: checkpoint f.relativePath(root) & ": does not link " & link
        check link in text

  # SPEC: NCK-KNOW-06
  test "NCK-KNOW-06 Given every details page, when its Public API section is compared with its module's jsondoc, then they agree":
    let (output, rc) = execCmdEx(quoteShell(root / "bin" / "api_sections") & " --check")
    if rc != 0: checkpoint output
    check rc == 0

suite "NCK-S style":
  # SPEC: NCK-STYLE-01
  test "NCK-STYLE-01 Given src, tools and tests, when beautifulnim checks them at warning level, then nothing is reported":
    var files: seq[string]
    for dir in ["src", "tools", "tests"]:
      for f in walkDirRec(root / dir):
        if f.endsWith(".nim"): files.add quoteShell(f)
    let (output, rc) = execCmdEx(quoteShell(root.parentDir / "beautifulnim" / "beautifulnim") &
      " check --min-level:warning " & files.join(" "))
    if rc != 0: checkpoint output
    check rc == 0

  # SPEC: NCK-STYLE-02
  test "NCK-STYLE-02 Given every exported routine of the knowledge modules, when its header is read, then it is a func, iterator or template, or a proc with raises: [] and a reason":
    for m in knowledgeSources():
      let lines = readFile(m).splitLines
      for i, line in lines:
        if not line.startsWith("proc "): continue
        var k = 5
        while k < line.len and line[k] in IdentChars: inc k
        if k >= line.len or line[k] != '*': continue
        var header = line
        var j = i
        while not header.strip.endsWith("=") and j + 1 < lines.len and j - i < 6:
          inc j
          header.add lines[j]
        let doc = if j + 1 < lines.len: lines[j + 1].strip else: ""
        let ok = "raises: []" in header and doc.startsWith("##")
        if not ok: checkpoint m.relativePath(root) & ":" & $(i + 1) & ": " & line.strip
        check ok
