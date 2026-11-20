# Spec: refactoring and migration patterns in Nim

Modules in `src/nimcs/patterns/`; tests in `tests/test_patterns_<module>.nim`. Each row is a law or an externally visible behaviour; laws are property tests (nim-propcheck). These five patterns change a system while it keeps running; every law says what stays the same while the shape changes.

| ID | Concept | Statement |
|---|---|---|
| PAT-PARALLELCHANGE-01 | parallel_change | For any sequence of writes through the legacy writer and the current writer, the legacy reader and the current reader of the record agree: the legacy answer is the legacy text of the current answer. |
| PAT-PARALLELCHANGE-02 | parallel_change | A record that holds only the legacy text, when it parses, reads back the same legacy text through the legacy reader and the parsed name through the current reader; a legacy text that does not parse reads as no current name. |
| PAT-PARALLELCHANGE-03 | parallel_change | `backfill` is idempotent, keeps the answer of both readers for every record, and leaves every parsable record with a current name. |
| PAT-PARALLELCHANGE-04 | parallel_change | `contract` refuses a store while any record has no current name, naming the first such record; after `backfill` of a store whose texts all parse it succeeds, and the current reader gives the same answer for every record before and after. |
| PAT-PARALLELCHANGE-05 | parallel_change | `initName` rejects an empty part and a comma, and for any accepted name `parseLegacy(formatLegacy(n))` is `n`. |
| PAT-STRANGLERFIG-01 | strangler_fig | `route` picks the target of the longest prefix of the request that is in the table, and the fallback when none is. |
| PAT-STRANGLERFIG-02 | strangler_fig | For any table, prefix and request, when the modern system answers the request as the legacy system does, `serve` gives the same response before and after `strangle` of that prefix; for a request that does not start with the prefix the route is unchanged. |
| PAT-STRANGLERFIG-03 | strangler_fig | `withRoute` is idempotent and the last write for a prefix wins; `retreat` after `strangle` of a prefix the table sent to legacy routes every request as the original table did. |
| PAT-STRANGLERFIG-04 | strangler_fig | A table whose fallback and every entry name the modern system never routes a request to legacy (`isRetired`); a table with a legacy entry or fallback is not retired. |
| PAT-STRANGLERFIG-05 | strangler_fig | `withRoute` rejects an empty prefix. |
