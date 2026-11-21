# Specification: design patterns (PAT), part resilience

Each row is a law or an externally visible behaviour; each ID has at least one tagged test in `tests/test_patterns_<concept>.nim`.

| ID | Concept | Statement |
|---|---|---|
| PAT-CIRCUITBREAKER-01 | circuit_breaker | Given a fresh breaker, when a call is asked at any time, then it is closed and allows |
| PAT-CIRCUITBREAKER-02 | circuit_breaker | Given any threshold, when failures arrive, then it opens at exactly the threshold-th consecutive failure |
| PAT-CIRCUITBREAKER-03 | circuit_breaker | Given failures below the threshold, when a success arrives, then the count restarts |
| PAT-CIRCUITBREAKER-04 | circuit_breaker | Given an open breaker, when asked before the pause is over (or when the clock reads earlier than the opening), then it refuses and is unchanged; at the pause it admits a probe |
| PAT-CIRCUITBREAKER-05 | circuit_breaker | Given a half-open breaker with a probe in flight, when another call is asked, then it refuses and is unchanged |
| PAT-CIRCUITBREAKER-06 | circuit_breaker | Given a probe, when it succeeds then the breaker closes; when it fails then it opens again from that time |
| PAT-CIRCUITBREAKER-07 | circuit_breaker | Given an open breaker, when a late success or failure arrives, then nothing changes |
| PAT-CIRCUITBREAKER-08 | circuit_breaker | Given any history of events with a growing clock, then a closed breaker has fewer failures than the threshold, a call passes an open breaker only after the pause, and a refusal never changes the breaker |
| PAT-CIRCUITBREAKER-09 | circuit_breaker | Given parameters out of range, when the config is built, then each gets its own error |
| PAT-CIRCUITBREAKER-10 | circuit_breaker | Given a breaker in each state, when its counters are read, then `consecutiveFailures` is the closed count and 0 when open or half-open, and `openedAtOf` is the opening tick when open and -1 when closed or half-open |
| PAT-BULKHEAD-01 | bulkhead | Given a compartment with a free permit, when acquired, then it is admitted and one more permit is in use |
| PAT-BULKHEAD-02 | bulkhead | Given a full compartment, when acquired, then it is refused and the bulkhead is unchanged |
| PAT-BULKHEAD-03 | bulkhead | Given any operations on one compartment, when applied, then no other compartment changes |
| PAT-BULKHEAD-04 | bulkhead | Given any sequence of acquires and releases, then permits in use stay within 0 and the limit and admission matches the free permits |
| PAT-BULKHEAD-05 | bulkhead | Given an admitted acquire, when the permit is released, then the bulkhead equals the one before |
| PAT-BULKHEAD-06 | bulkhead | Given nothing taken or an unknown name, when releasing or acquiring, then each gets its own answer and nothing changes |
| PAT-BULKHEAD-07 | bulkhead | Given invalid compartments, when the bulkhead is built, then each rule gets its own error; usage is sorted by name |
| PAT-TOKENBUCKET-01 | token_bucket | Given a new bucket, when its tokens are counted at the start, then it holds exactly its capacity |
| PAT-TOKENBUCKET-02 | token_bucket | Given any bucket, when n tokens are asked at one time, then a grant takes exactly n and a refusal takes none |
| PAT-TOKENBUCKET-03 | token_bucket | Given any requests with a growing clock, then the tokens granted never exceed capacity plus rate times elapsed |
| PAT-TOKENBUCKET-04 | token_bucket | Given any history, then the tokens held never exceed the capacity and never go below zero |
| PAT-TOKENBUCKET-05 | token_bucket | Given a used bucket, when it is refilled at an intermediate time first, then the result equals refilling directly; refilling twice at one time equals once |
| PAT-TOKENBUCKET-06 | token_bucket | Given a drained bucket, when enough time has passed, then it is full again and not before |
| PAT-TOKENBUCKET-07 | token_bucket | Given a clock that goes backwards or a request larger than the capacity, when tokens are asked, then none are created and the request is refused |
| PAT-TOKENBUCKET-08 | token_bucket | Given parameters out of range, when the config is built, then each gets its own error; the largest parameters do not overflow |
| PAT-SAGA-01 | saga | Given any number of steps that all succeed, when run, then it completes with the actions in order and no compensation |
| PAT-SAGA-02 | saga | Given step k fails, when run, then actions up to k ran, then compensations of k-1 down to 0 in reverse, and k itself is not compensated |
| PAT-SAGA-03 | saga | Given the first step fails, when run, then it ends compensated with one log entry and no compensation |
| PAT-SAGA-04 | saga | Given a compensation fails, when run, then it stops stuck, nothing further runs, and pending lists the rest in order |
| PAT-SAGA-05 | saga | Given any failing step, when run to the end, then every action that succeeded has exactly one successful compensation |
| PAT-SAGA-06 | saga | Given a finished or stuck saga, when more results are fed, then the saga does not change |
| PAT-SAGA-07 | saga | Given the same plan, when an imperative shell steps through nextEffect and feed, then it ends in the saga that run returns with the same effects |
| PAT-SAGA-08 | saga | Given no steps, when started, then it is completed with an empty log |
| PAT-SAGA-09 | saga | Given a started saga, when asked what to do, then it names the first action and each result moves it to the next effect |
| PAT-TXOUTBOX-01 | transactional_outbox | Given a unit, when a change is recorded with messages, then the new state and the messages arrive together with sequential unique ids |
| PAT-TXOUTBOX-02 | transactional_outbox | Given a recorded change, when the messages are read, then they keep topic, payload and order |
| PAT-TXOUTBOX-03 | transactional_outbox | Given any outbox, when a batch is asked, then it is the oldest messages up to the count and the outbox is unchanged |
| PAT-TXOUTBOX-04 | transactional_outbox | Given any delivery results, when settled, then exactly the undelivered messages remain, in order |
| PAT-TXOUTBOX-05 | transactional_outbox | Given any results, when they are settled twice, then the outbox equals settling once; no successes change nothing |
| PAT-TXOUTBOX-06 | transactional_outbox | Given delivered messages, when new messages are recorded, then their ids are never reused |
| PAT-TXOUTBOX-07 | transactional_outbox | Given rounds in which acknowledgements are lost, when the relay retries, then every message is applied exactly once by an idempotent receiver and the outbox ends empty |
