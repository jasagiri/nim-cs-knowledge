# G2 mutation testing

Measured 2026-11-21 with nim-muter 0.2.18, mutators AOR ROR LOR BLR SDL RVR LBR CVR, for the eight
modules added in round "5-handover". Each module ran against its own test file only. Survivors are
classified in the ledgers below; `nim-muter-ledger check <ledger>` exits 0 only when none is
undecided, test_owed or spec_question. The modules written before that round are not measured yet
(未測定); no G2 figure is claimed for them.

| Module | Mutants (compile errors left out) | Killed at first | Killed now | Timeouts | Survived | Ledger |
|---|---|---|---|---|---|---|
| `patterns/circuit_breaker.nim` | 24 | 17 | 23 | 0 | 1 (unreached) | `survivors-patterns.json` |
| `patterns/bulkhead.nim` | 34 | 31 | 32 | 0 | 2 (equivalent) | `survivors-patterns.json` |
| `patterns/saga.nim` | 51 | 38 | 51 | 0 | 0 | — |
| `patterns/token_bucket.nim` | 35 | 30 | 34 | 0 | 1 (equivalent) | `survivors-patterns.json` |
| `patterns/transactional_outbox.nim` | 20 | 16 | 20 | 0 | 0 | — |
| `ds/write_ahead_log.nim` | 69 | 63 | 67 | 0 | 2 (equivalent) | `survivors-ds.json` |
| `ds/consistent_hashing.nim` | 71 | 47 | 58 | 6 | 7 (equivalent) | `survivors-ds.json` |
| `ds/crdt.nim` | 134 | 97 | 119 | 9 | 6 (equivalent) | `survivors-ds.json` |

Timeouts are mutants that never finish (a dropped `inc`, or `mid + 1` changed in a binary search);
they are detected, and counted apart from killed.

How the numbers came about:

- The first run left 84 survivors. Tests added for existing spec IDs killed 63 of them.
- Two survivors of `circuit_breaker.nim` (the value of `consecutiveFailures` when not closed, and of
  `openedAtOf` when not open) needed a behaviour that only a doc comment stated. It is now
  PAT-CIRCUITBREAKER-10, with its test; both mutants are killed.
- The 4 `return err(..., <first value>)` survivors are equivalent because `default(Result)` is the
  error variant holding the first enum value. Reordering those enums would make them killable.
- Equivalence was argued by reading the code; the reasons are in the ledgers.

## Running it again

- The repository's VCS configuration has the extension `relativeWorktrees`, which Apple's build of
  the VCS tool cannot read, and nim-muter stops when it first asks that tool for the tracked files.
  The campaign therefore runs in a copy without the VCS directories:
  `rsync -a --delete --exclude=.git --exclude=.jj --exclude=target --exclude=nimcache nim-cs-knowledge/ W/foundation/nim-cs-knowledge/`,
  with `free-books-catalog` and `nim-propcheck` linked next to it in `W/foundation/` (the paths in
  `nim.cfg`). nim-muter then warns that this is not a work tree and uses its built-in ignore rules.
  Tests are written in the repository and copied again before a run.
- `export DEVELOPER_DIR=/Library/Developer/CommandLineTools` if Xcode's licence blocks the C
  compiler.
- One configuration per module, run in the copy as `nim-muter --config <file> --workspace "$PWD"`:

```json
{
  "sources": ["src/nimcs/patterns/circuit_breaker.nim"],
  "testCommand": "nim c -r --hints:off tests/test_patterns_circuit_breaker.nim",
  "mutators": ["AOR","ROR","LOR","BLR","SDL","RVR","LBR","CVR"],
  "parallelism": 1,
  "testOutput": "unittest",
  "outputDir": "<outside the repository>",
  "reports": ["console","json"],
  "incremental": false
}
```

- Then `nim-muter-ledger sync <outputDir>/report.json docs/quality/survivors-<area>.json` and
  `nim-muter-ledger check` on each ledger.
