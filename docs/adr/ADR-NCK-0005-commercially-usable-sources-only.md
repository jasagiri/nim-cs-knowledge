# ADR-NCK-0005: Only sources whose licence allows commercial use, chosen per page

**ADR ID**: ADR-NCK-0005
**Status**: accepted
**Date**: 2026-11-22
**Author**: jasagiri (drafted by Claude Opus 5.5)

## Context

ADR-NCK-0001 built the catalog from free-programming-books and the Hillside patterns catalog,
followed to depth 2: about twelve thousand sources. Each page cited the books whose table of
contents names its concept (catalog/concepts.json). Most of those books state no licence or one that
forbids commercial use (for example the Competitive Programmer's Handbook, CC BY-NC-SA). jasagiri
asked on 2026-11-22 for the knowledge repositories to hold only what can be used commercially, as
unix-admin-knowledge (ADR-UADM-0004) and modern-cli-knowledge (ADR-MCLI-0004) now do.

## Requirements

- Every source the repository lists can be used commercially, for example built into a company's
  own systems.
- A source without such a licence cannot enter the catalog, and a test fails if one is committed.
- A page cites a source only if the source explains the page's concept; where none does, the page
  says so instead of citing something loosely related.
- The citations are data that a tool turns into the pages, as before (cite_sources), not hand edits.

## Options

- A. List, per page, the articles and chapters that explain its concept from sites whose licence was
  read (Wikipedia, cp-algorithms, Erickson's textbook, Open Data Structures, the Erlang/OTP
  documentation), keep the page-to-source choice in catalog/citations.json, switch
  free-programming-books and Hillside off and `commercialOnly` on.
- B. Keep the book catalog and cite only the books whose list line states an allowed licence.
- C. Keep the catalog and drop only the citations that are not usable commercially.

## Trade-offs

- A cites a source that explains the concept itself, rather than a book whose contents name it, and
  the builder enforces the licence. Some concepts have no article on these sites (11 of 159 pages);
  those pages cite nothing and say why. Encyclopaedia articles are less deep than textbooks.
- B keeps the textbooks, but few list lines state a licence, and a stated licence is the list
  maintainers' reading, not the book's own terms; the books with an allowed licence cover few pages.
- C still ships a catalog listing works that cannot be used commercially.

## Decision

A.

- `catalog/config.json` has `"fpb": false`, `"hillside": false` and `"commercialOnly": true`; it lists
  196 sources, each with the SPDX identifier of its site's licence (`docs/sources.md` says where each
  was read). NCK-SRC-01 and NCK-SRC-02 check the committed catalog.
- `catalog/citations.json` holds, per page, the URLs it cites, what each covers, and a note: why no
  source is cited, or what the cited ones leave out. Every page has an entry and every listed source
  is cited (NCK-SRC-03). `tools/cite_sources` writes the Sources sections from it;
  `catalog/concepts.json` is gone.
- The sources were chosen by opening each candidate and checking that it explains the concept; an
  article on a broader topic is cited only when no specific one exists, and the note says so.
- The pages copy no text from these sources (ADR-NCK-0001).

## Not decided here

- Whether to add further sites with commercially usable licences (for example other textbooks under
  CC BY) to cover the 11 pages that cite nothing.

## Rejected alternatives

B and C, for the reasons under Trade-offs.
