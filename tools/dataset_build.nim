## dataset_build [--root:<repo>] [--out:<dir>]
##
## skills/*/details/*.md + their modules and tests → dataset/records.jsonl and dataset/chat.jsonl
## (ADR-NCK-0003). No network, no clock (NCK-DATA-01). Exit 0 on success, 2 on a usage error.

import std/[os, parseopt]
import nimcs/dataset
import page_index

proc main(): int =
  var root = currentSourcePath().parentDir.parentDir
  var outDir = ""
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "root": root = val
      of "out": outDir = val
      else:
        stderr.writeLine "dataset_build: unknown option --" & key
        return 2
    of cmdArgument:
      stderr.writeLine "dataset_build: unexpected argument " & key
      return 2
    of cmdEnd: discard # getopt never yields cmdEnd inside the loop
  if outDir.len == 0: outDir = root / "dataset"
  var records: seq[Record]
  for c in collect(root): records.add recordsOf(c)
  let (recs, chat) = render(records)
  createDir(outDir)
  writeFile(outDir / "records.jsonl", recs)
  writeFile(outDir / "chat.jsonl", chat)
  echo "dataset_build: ", records.len, " records → ", outDir
  0

when isMainModule:
  quit main()
