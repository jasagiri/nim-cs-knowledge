# Specification — tools and repository checks

The knowledge itself is specified per area in `docs/spec/*.md` (one table each, IDs `FP-`, `DS-`,
`SORT-`, `GRAPH-`, `DP-`, `GOF-`, `PAT-` …). This file specifies the catalog, the dataset and the
checks that hold the repository together. Every ID has a test tagged `# SPEC: <ID>`;
`nim specCoverage` checks that (G1).

## Catalog (ADR-NCK-0001)

| ID | Statement |
|---|---|
| NCK-CAT-01 | catalog/meta.json, sources.jsonl and triage.json are what free-books-catalog (its FBC-01…FBC-10) builds from catalog/config.json and the fetched pages: rebuilding from the cache gives the committed bytes. The check runs where the cache is present. |
| NCK-CAT-02 | No module under src/ or tools/ imports a networking module; the network is used only by free-books-catalog's catalog_fetch. |
| NCK-SRC-01 | Every source in catalog/sources.jsonl states at least one licence, and each is one of `commercialLicenses` in free-books-catalog (src/free_books_catalog/licences.nim: licences that allow use, copying, modification and distribution for any purpose, commercial use included). |
| NCK-SRC-02 | catalog/config.json switches free-programming-books (`fpb`) and Hillside off and `commercialOnly` on, so the catalog holds exactly the sources it lists and catalog_build refuses a source whose licences are not on the list. |
| NCK-SRC-03 | catalog/citations.json has one entry per details page; an entry with no source has a note saying why; the URLs it cites are exactly the sources catalog/config.json lists. |

## Knowledge pages and modules (ADR-NCK-0002)

| ID | Statement |
|---|---|
| NCK-KNOW-01 | Every details page has the sections Intent, Use when / avoid when, Nim shape, Public API, Laws and invariants, Complexity, Pitfalls, Related, Sources, in that order, and at least one `nim bad` block under Pitfalls. |
| NCK-KNOW-02 | Every `nim` block of every SKILL.md and details page compiles on its own under the repository's lint settings; fences are only `nim` and `nim bad`. |
| NCK-KNOW-03 | Every Sources section cites at least one catalog ID, or states `None in the catalog:` with the reason; every cited ID exists in catalog/sources.jsonl. |
| NCK-KNOW-04 | Every details page names a module that exists, and every knowledge module has a details page. |
| NCK-KNOW-05 | Every SKILL.md has `name` and `description` front matter and links every details page of its skill. |
| NCK-KNOW-06 | Every details page's Public API section lists exactly the exported symbols of its module, as `nim jsondoc` reports them (`bin/api_sections --check` exits 0). |

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
