## catalog_build [--raw:<dir>] [--out:<dir>]
##
## raw/ → catalog/meta.json, catalog/sources.jsonl, catalog/triage.json. No network, no clock:
## running it twice on the same raw/ gives the same bytes (NCK-CAT-06). Exit 0 on success, 1 when
## raw/ is incomplete, 2 on a usage error.

import std/[os, parseopt]
import nimcs/catalog/build
import ./rawstore

proc main(): int =
  var raw = defaultRaw()
  var outDir = currentSourcePath().parentDir.parentDir / "catalog"
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "raw": raw = val
      of "out": outDir = val
      else:
        stderr.writeLine "catalog_build: unknown option --" & key
        return 2
    of cmdArgument:
      stderr.writeLine "catalog_build: unexpected argument " & key
      return 2
    of cmdEnd: discard # getopt never yields cmdEnd inside the loop
  if not dirExists(raw / "fpb"):
    stderr.writeLine "catalog_build: " & raw & "/fpb is missing; run catalog_fetch fpb first"
    return 1
  let inputs = readInputs(raw, outDir / "overrides.json")
  if inputs.fpbCommit.len == 0:
    stderr.writeLine "catalog_build: " & raw & "/manifest.json has no fpbCommit"
    return 1
  let output = assemble(inputs)
  createDir(outDir)
  writeFile(outDir / "meta.json", output.metaJson)
  writeFile(outDir / "sources.jsonl", output.sourcesJsonl)
  writeFile(outDir / "triage.json", output.triageJson)
  echo "catalog_build: ", output.sources.len, " sources → ", outDir
  0

when isMainModule:
  quit main()
