## E tests for docs/specification.md NCK-CAT-01…NCK-CAT-02 (the catalog, built by free-books-catalog).

import std/[os, strutils, unittest]

const root = currentSourcePath().parentDir.parentDir

suite "catalog":
  # SPEC: NCK-CAT-01
  test "NCK-CAT-01 Given the committed catalog, when rebuilt from the cache with free-books-catalog, then it is unchanged (skipped without the cache)":
    let raw = getEnv("NIMCS_RAW", getHomeDir() / ".cache" / "nim-cs-knowledge" / "raw")
    if not fileExists(raw / "manifest.json"):
      skip()
    else:
      let tmp = getTempDir() / "nck-catalog-rebuild"
      removeDir(tmp)
      createDir(tmp)
      let rc = execShellCmd(quoteShell(root / "bin" / "catalog_build") &
        " --config:" & quoteShell(root / "catalog" / "config.json") &
        " --raw:" & quoteShell(raw) & " --out:" & quoteShell(tmp) & " > /dev/null")
      check rc == 0
      for f in ["meta.json", "sources.jsonl", "triage.json"]:
        check readFile(tmp / f) == readFile(root / "catalog" / f)

  # SPEC: NCK-CAT-02
  test "NCK-CAT-02 Given every module under src/ and tools/, when its imports are read, then none is a networking module":
    for dir in ["src", "tools"]:
      for f in walkDirRec(root / dir):
        if not f.endsWith(".nim"): continue
        for line in readFile(f).splitLines:
          let t = line.strip
          if t.startsWith("import ") or t.startsWith("from "):
            for banned in ["httpclient", "asynchttpserver", "net", "asyncnet", "nativesockets"]:
              check banned notin t.multiReplace(("[", " "), ("]", " "), (",", " ")).splitWhitespace
