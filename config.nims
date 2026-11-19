# Development tasks (`nim <task>`); listed at the end of `nim help`.
#
#   nim test           every tests/test_*.nim (knowledge modules, catalog, pages, dataset, style)
#   nim catalog        rebuild catalog/ from the fetched pages with ../free-books-catalog (no network)
#   nim apiSections    rewrite the Public API section of every details page from its module
#   nim dataset        rebuild dataset/ from skills/, src/, tests/ and catalog/
#   nim specCoverage   G1 table → docs/quality/g1-spec-coverage.md
#
# Not nimble tasks: `test` clashes with nimble's built-in command, and nimble would resolve
# dependencies. The repository does not choose where executables go, except the tools,
# which the tests run from bin/.

import std/[algorithm, os, strutils]

proc testFiles(): seq[string] =
  for f in listFiles("tests"):
    let name = f.extractFilename
    if name.startsWith("test_") and name.endsWith(".nim"): result.add f
  result.sort()

proc buildTools() =
  mkDir("bin")
  exec "nim c --hints:off -d:release -o:bin/catalog_build ../free-books-catalog/tools/catalog_build.nim"
  exec "nim c --hints:off -d:release -o:bin/dataset_build tools/dataset_build.nim"
  exec "nim c --hints:off -d:release -o:bin/api_sections tools/api_sections.nim"

task test, "all tests":
  buildTools()
  for t in testFiles():
    echo "== " & t
    exec "nim c -r --hints:off " & t
  # The iterative destructors rely on isUniqueRef, whose value Nim says may change with the compiler
  # version and optimiser settings; run their drop tests in a release build as well.
  for t in ["tests/test_ds_cons_list.nim", "tests/test_ds_pairing_heap.nim", "tests/test_ds_leftist_heap.nim"]:
    echo "== " & t & " (release)"
    exec "nim c -r --hints:off -d:release " & t

task catalog, "rebuild catalog/ from raw/":
  buildTools()
  exec "bin/catalog_build --config:catalog/config.json"

task apiSections, "rewrite the Public API sections":
  buildTools()
  exec "bin/api_sections"

task dataset, "rebuild dataset/":
  buildTools()
  exec "bin/dataset_build"

task specCoverage, "G1 table":
  var args = ""
  for f in listFiles("docs/spec"):
    if f.endsWith(".md"): args.add " --spec-table " & f
  exec "../nim-spec-coverage/bin/tools/spec_coverage . --spec-table docs/specification.md" & args &
    " > docs/quality/g1-spec-coverage.md"
