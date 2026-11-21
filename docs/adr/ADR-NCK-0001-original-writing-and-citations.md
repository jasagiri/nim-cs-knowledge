# ADR-NCK-0001: A catalog of free sources, and original writing that cites it

**ADR ID**: ADR-NCK-0001
**Status**: accepted
**Date**: 2026-11-19
**Author**: jasagiri (drafted by Claude Opus 5.5)

## Context

The knowledge in this repository is meant to come from free books and pattern catalogs: the lists
of free-programming-books (EbookFoundation) and the Hillside Group's patterns catalog, followed
recursively. The repository is meant to be published (Apache-2.0) and its dataset used to train
models. "Free to read" is not "free to copy": most of the listed books are under all-rights-reserved
or non-commercial / no-derivatives terms, and many pattern pages state no licence at all.

## Requirements

- Show which sources exist, which were considered, and what became of each (reachable, dead,
  refused, not followed), so the coverage is checkable rather than claimed.
- Publish nothing that copies a source's text or code.
- Tie every concept to the sources that teach it, so a reader can go to the original.
- Bound the crawl: the lists link to whole sites (tutorial portals, archives) that have no end.

## Options

1. **Mirror the books** and extract text into the dataset. Maximal coverage; legally impossible to
   publish for most sources, and a licence-by-licence filter would leave a skewed remainder.
2. **Quote passages under their licences** (CC BY, CC BY-SA) with attribution. Possible for a
   minority; share-alike terms would bind the dataset, and the rest stays uncovered.
3. **A catalog of facts plus original writing.** Record the facts of each source (title, URL,
   section, stated licence, reachability); write every explanation and every line of code new; cite
   sources by catalog ID.

## Trade-offs

Option 3 publishes only facts (titles, URLs and the free-programming-books arrangement, which is
CC BY 4.0 and attributed in NOTICE) and our own text. It gives up verbatim fidelity to the books,
which is the price of a publishable dataset; it keeps the books one click away. Reading a source to
learn which concepts it covers is allowed; carrying its text back is not.

## Decision

Option 3.

- **The crawl** (tools/catalog_fetch.nim) starts at every list file of free-programming-books at a
  pinned commit and at every page of the Hillside catalog and its eight book categories (depth 1).
  It follows one more level (depth 2) only for lists that are one page of links: every Hillside web
  link (each is an external pattern catalog) and free-programming-books meta-lists hosted on GitHub
  (their README). Other meta-lists are whole sites; they are recorded with the reason they were not
  followed. Nothing beyond depth 2 is fetched.
- **Politeness**: one request at a time per host with a delay, robots.txt honoured, a descriptive
  user agent, every failure recorded as a state.
- **Concept mapping**: sources classed core are examined by their table of contents to list the
  concepts they cover (catalog/concepts.json). Only concept names and source IDs are kept.
- **Writing**: every details page, module, test and dataset record is written for this repository.
  Workers (people or agents) are told not to fetch or copy sources while writing.
- **Citation**: each details page ends with a Sources section listing catalog IDs; a test fails when
  an ID is not in catalog/sources.jsonl.

## Not decided here

- Which licence the dataset itself carries beyond the repository's Apache-2.0.
- Whether to add other start points (arXiv surveys, university course notes) later; that would be a
  new ADR, since it changes the coverage claim.

## Rejected alternatives

Options 1 and 2 above.

## 訂正 (2026-11-19)

- The catalog code (parsing, triage, crawl, build) and the tools `catalog_fetch` and `catalog_build`
  moved to the sibling package free-books-catalog (ADR-FBC-0001), which a second repository also
  uses. This repository keeps its keywords and start points in `catalog/config.json`. The decisions
  above (start points, depth 2, politeness, facts only) are unchanged. The rebuild with the moved
  code gave byte-identical `catalog/` files (NCK-CAT-01). Where this ADR names
  `tools/catalog_fetch.nim`, read free-books-catalog's `tools/catalog_fetch.nim`.

## 訂正 (2026-11-22)

- The catalog no longer holds free-programming-books or the Hillside catalog, and is no longer
  crawled to depth 2: it lists only the per-page sources whose licences allow commercial use
  (ADR-NCK-0005). The crawl and the concept mapping (catalog/concepts.json) above describe the catalog
  as it was built before; the decisions on original writing and citing by catalog ID stand.
