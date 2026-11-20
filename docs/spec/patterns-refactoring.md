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
| PAT-BRANCHBYABSTRACTION-01 | branch_by_abstraction | For any items and any two implementations that satisfy the same contract, the client gives the same total at every stage of the migration. |
| PAT-BRANCHBYABSTRACTION-02 | branch_by_abstraction | At the shadow stage the answer is always the old implementation's answer, and a mismatch is reported exactly when the two implementations differ on the items. |
| PAT-BRANCHBYABSTRACTION-03 | branch_by_abstraction | At the new stage the answer is the new implementation's answer whatever the old one returns, and at the old stage the old one's. |
| PAT-BRANCHBYABSTRACTION-04 | branch_by_abstraction | `advance` moves old to shadow to new and stays at new; `retreat` moves back one step and stays at old; advancing then retreating from old or shadow returns to the start. |
| PAT-ANTICORRUPTIONLAYER-01 | anti_corruption_layer | For any order of the inner model, translating its image in either supplier format gives back that order; the two formats give the same order. |
| PAT-ANTICORRUPTIONLAYER-02 | anti_corruption_layer | For any supplier record, translation is either a specific refusal or an order whose id is not empty and whose total is not negative; an unknown status code, a malformed amount and an empty id are each refused with their own error. |
| PAT-ANTICORRUPTIONLAYER-03 | anti_corruption_layer | The inner model's operations do not accept a supplier record: passing one is a compile error. |
| PAT-ANTICORRUPTIONLAYER-04 | anti_corruption_layer | `translateAll` keeps accepted orders in input order and lists each refusal with its input index, so that accepted plus refused equals the input length. |
| PAT-SEAM-01 | seam | For any list of known SKUs, the total through the default seam equals the total of the hard-wired routine it replaced (the one difference, an unknown SKU, is PAT-SEAM-03). |
| PAT-SEAM-02 | seam | For any price function supplied as the seam, the total of a list of known SKUs equals the sum of its prices with the bulk discount, as an independent model computes it. |
| PAT-SEAM-03 | seam | A SKU the seam does not know makes the total an error naming the first such SKU; no price is invented. |
| PAT-SEAM-04 | seam | Pins taken from a routine hold for that routine; for a routine that differs on some pinned input, `firstDifference` is the index of the first such input and `holds` is false. |
