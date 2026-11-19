# Specification — tools and repository checks

The knowledge itself is specified per area in `docs/spec/*.md` (one table each, IDs `FP-`, `DS-`,
`SORT-`, `GRAPH-`, `DP-`, `GOF-`, `PAT-` …). This file specifies the catalog, the dataset and the
checks that hold the repository together. Every ID has a test tagged `# SPEC: <ID>`;
`nim specCoverage` checks that (G1).

## Catalog (ADR-NCK-0001)

| ID | Statement |
|---|---|
| NCK-CAT-01 | A free-programming-books list line `* [title](url) - authors (formats) (licence)` becomes one source with its title, URL, authors, formats, stated licences, archived flag, the heading path above it and the list's language; lines that are not entries (index links, headings, prose) become nothing. |
| NCK-CAT-02 | A source's ID is FNV-1a 64 over the normalized URL (lower-case scheme and host, no fragment, no trailing slash); normalization is idempotent; sources with one ID merge into one, keeping every listing, and merging is order-independent. |
| NCK-CAT-03 | Each Hillside catalog page yields its web links (id and title) and the start of the next page; each Hillside book category yields its book pages; a web link whose redirect is known is catalogued under its target URL. |
| NCK-CAT-04 | Only hillside web links and GitHub-hosted free-programming-books meta-lists are followed to depth 2; their links become depth-2 listings that name the list they came from, at most 2000 per list; every other meta-list is recorded in meta.json with the reason it was not followed. |
| NCK-CAT-05 | Every source has exactly one relevance: core when a heading of one of its listings or its title matches a keyword (short keywords only as whole words), all hillside depth-1 entries core, screencasts and playgrounds out, otherwise adjacent; a hand decision in catalog/overrides.json wins. |
| NCK-CAT-06 | Building twice from the same inputs gives byte-identical meta.json, sources.jsonl and triage.json, whatever the order the inputs were read in; every line of sources.jsonl is valid UTF-8 JSON. |
| NCK-CAT-07 | No module under src/ imports a networking module; only tools/catalog_fetch.nim does. |

## Knowledge pages and modules (ADR-NCK-0002)

| ID | Statement |
|---|---|
| NCK-KNOW-01 | Every details page has the sections Intent, Use when / avoid when, Nim shape, Laws and invariants, Complexity, Pitfalls, Related, Sources, in that order, and at least one `nim bad` block under Pitfalls. |
| NCK-KNOW-02 | Every `nim` block of every SKILL.md and details page compiles on its own under the repository's lint settings; fences are only `nim` and `nim bad`. |
| NCK-KNOW-03 | Every Sources section cites at least one catalog ID, or states `None in the catalog:` with the reason; every cited ID exists in catalog/sources.jsonl. |
| NCK-KNOW-04 | Every details page names a module that exists, and every knowledge module has a details page. |
| NCK-KNOW-05 | Every SKILL.md has `name` and `description` front matter and links every details page of its skill. |

## Style (ADR-NCK-0002)

| ID | Statement |
|---|---|
| NCK-STYLE-01 | `beautifulnim check --min-level:warning` reports nothing on src/, tools/ and tests/. |
| NCK-STYLE-02 | Every exported routine of a knowledge module (src/nimcs/fp, ds, algo, patterns) is a `func`, `iterator` or `template`, or a `proc` that declares `raises: []` and says in its doc comment why it is not a `func`. |

## Dataset (ADR-NCK-0003)

| ID | Statement |
|---|---|
| NCK-DATA-01 | Building the dataset twice from the same repository gives byte-identical records.jsonl and chat.jsonl, sorted by record id, with unique ids. |
| NCK-DATA-02 | Every record has the fields of ADR-NCK-0003 with a known kind, non-empty instruction and output, and its specIds and files exist in the repository. |
| NCK-DATA-03 | An `implement` record's output is the module file verbatim; a `law` record's output is the tagged test verbatim; a `refactor` record pairs a `nim bad` block with the `nim` block after it. |
| NCK-DATA-04 | Every chat record has a system, a user and an assistant message, and corresponds one-to-one to a record. |
