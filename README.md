# nim-cs-knowledge

Algorithms, data structures and design patterns written as **functional, idempotent, modern Nim**:
tested modules, agent skills that teach them, and a training dataset derived from both. Every
concept is tied to the free books and pattern catalogs that teach it.

[BeautifulNim](../beautifulnim) teaches *how* Nim is written (naming, effects, ownership, errors).
This repository teaches *what* to build with it, in the same house style (ADR-NCK-0002): public
routines are `func` with `{.raises: [].}`, failure is `Option`/`Result`, data is plain objects and
object variants, updates return new values, and every law (idempotence, round trip, associativity,
structural invariants) is a property test.

| Path | What it is |
|---|---|
| `src/nimcs/fp/` | functional foundations: Result, Option, folds, composition, lazy streams, ADTs, smart constructors, idempotence, monoids |
| `src/nimcs/ds/` | persistent data structures: lists, queues, deques, heaps, red-black trees, skew lists, vectors, HAMT, tries, zippers, union-find, segment trees, Bloom filters, Merkle trees and content-addressed stores |
| `src/nimcs/algo/` | sorting, searching, graphs, dynamic programming, string search, number theory, backtracking, greedy, divide and conquer |
| `src/nimcs/patterns/` | the 23 GoF patterns in functional form (and which ones disappear), plus functional architecture patterns: functional core, event sourcing, CQRS, interpreters, tagless final, lenses, parser combinators, idempotent commands, and refactoring and migration patterns (parallel change, strangler fig, branch by abstraction, anti-corruption layer, seam) |
| `skills/*/SKILL.md`, `details/` | agent skills (Agent Skills format), one details page per concept |
| `docs/spec/*.md` | the laws and behaviours of each concept, by spec ID; tests are tagged with them |
| `catalog/` | the sources: every entry of free-programming-books and the Hillside patterns catalog, followed to depth 2, with relevance, reachability and the concepts each core source covers; built by `../free-books-catalog` from `catalog/config.json` |
| `dataset/` | `records.jsonl` and `chat.jsonl`, generated from the pages, modules and tests |
| `tools/` | `cite_sources`, `dataset_build` (no network) |
| `docs/adr/` | why: sources and copyright (0001), style (0002), dataset (0003) |

## Using the skills

Copy or link the four directories under `skills/` into `~/.claude/skills/` (or a project's
`.claude/skills/`), next to BeautifulNim's. The pages import the modules as `nimcs/<area>/<name>`;
add this repository's `src/` to the path (`--path:"<repo>/src"`) to compile them.

## Using the dataset

`dataset/records.jsonl` has one record per line: `id`, `kind` (`explain`, `implement`, `refactor`,
`law`), `area`, `concept`, `instruction`, `input`, `output`, `specIds`, `sources` (catalog IDs) and
`files` (where it came from). `dataset/chat.jsonl` holds the same records as system/user/assistant
messages. Every code answer is a file this repository compiles and tests. Regenerate with
`nim dataset`; the bytes do not change unless the sources do.

## Sources and copyright

The catalog records facts only (title, URL, section, stated licence, reachability). No text or
code was copied from any listed book or page; everything under `src/`, `skills/` and `dataset/` was
written here and cites sources by catalog ID (ADR-NCK-0001, NOTICE). The free-programming-books
arrangement is CC BY 4.0 and attributed in NOTICE.

## Development

Needs Nim 2.4.2 and, next to this repository, `../beautifulnim` (lint settings and checker),
`../nim-propcheck` (property tests) and `../free-books-catalog` (builds and fetches the catalog).

```sh
nim test           # modules, catalog, pages (every code block compiles), style, dataset
nim catalog        # catalog/ from the fetched pages in raw/ (no network; ../free-books-catalog)
nim dataset        # dataset/ from skills/, src/, tests/, catalog/
nim specCoverage   # G1 table (needs ../nim-spec-coverage)

# refreshing the sources (network; one request per host at a time, robots.txt honoured)
nim c -d:ssl -d:release -o:bin/catalog_fetch ../free-books-catalog/tools/catalog_fetch.nim
bin/catalog_fetch fpb   # then: hillside, expand, reach (reads catalog/config.json)
```

`raw/` (the fetched pages) lives outside the repository: `$NIMCS_RAW`, by default
`~/.cache/nim-cs-knowledge/raw`; the tools also take `--raw:<dir>`.
