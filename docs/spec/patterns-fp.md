# Spec: functional and architectural patterns in Nim

Modules in `src/nimcs/patterns/`; tests in `tests/test_patterns_<module>.nim`. Each row is a law or an externally visible behaviour; laws are property tests (nim-propcheck).

| ID | Concept | Statement |
|---|---|---|
| PAT-FUNCTIONALCORE-01 | functional_core | For any heater state and reading, `decide` emits no effect when the state is unchanged, and otherwise exactly one `ekSetHeater` naming the new state followed by one `ekLog`. |
| PAT-FUNCTIONALCORE-02 | functional_core | Deciding again with the state a decision returned and the same reading emits no effects and keeps that state. |
| PAT-FUNCTIONALCORE-03 | functional_core | A reading within `band` of the target keeps the state and emits nothing; below `target - band` the heater goes on, above `target + band` it goes off. |
| PAT-FUNCTIONALCORE-04 | functional_core | For any readings, a shell that performs the effects the core returns ends with the heater in the core's final state and one log line per switch. |
| PAT-FUNCTIONALCORE-05 | functional_core | `initConfig` rejects a negative band and keeps the target and band of a valid one. |
| PAT-EVENTSOURCING-01 | event_sourcing | For any log and event, replaying the log with the event appended equals applying the event to the replayed state; replaying the same log twice gives equal states. |
| PAT-EVENTSOURCING-02 | event_sourcing | For any log and cut, the snapshot at the cut extended with the remaining tail equals the full replay. |
| PAT-EVENTSOURCING-03 | event_sourcing | For any log, the replayed version is the log's length and the balance is deposits minus withdrawals. |
| PAT-EVENTSOURCING-04 | event_sourcing | `appended` returns a log one longer ending in the new event and leaves the original log unchanged. |
| PAT-EVENTSOURCING-05 | event_sourcing | `snapshotAt` with a count of 0 or less is the empty account, and with a count beyond the log is the full replay. |
| PAT-CQRS-01 | cqrs | `decide` refuses an empty sku, a non-positive quantity, and shipping more than is on hand, each with its own error and no event; an accepted command yields exactly one event stating it. |
| PAT-CQRS-02 | cqrs | For any commands submitted one by one, every stock line stays positive and the lines stay sorted by sku with no duplicate. |
| PAT-CQRS-03 | cqrs | For any two event logs, projecting the second onto the dashboard of the first equals the dashboard of both concatenated. |
| PAT-CQRS-04 | cqrs | For any commands, the units on hand in the stock projection equal units received minus units shipped in the dashboard. |
| PAT-CQRS-05 | cqrs | For any commands, rebuilding the stock from the event log equals the live stock, and every command is either an event or a refusal. |
| PAT-STATEMACHINE-01 | state_machine | Every row of the transition table, stepped, moves to the row's target state. |
| PAT-STATEMACHINE-02 | state_machine | Every (state, input) pair without a row is rejected with an error naming exactly that pair. |
| PAT-STATEMACHINE-03 | state_machine | For any start and inputs, a successful `run` ends in a state in `reachable(start)`; `reachable(osCreated)` is every state. |
| PAT-STATEMACHINE-04 | state_machine | A terminal state rejects every input and has no allowed inputs. |
| PAT-STATEMACHINE-05 | state_machine | No (state, input) pair appears in two rows of the table. |
| PAT-STATEMACHINE-06 | state_machine | Running two input lists in one go equals running the first and then the second from its final state; the error is the first invalid step. |
| PAT-FREEINTERPRETER-01 | free_interpreter | For any two programs, `runPure` of their concatenation gives the store and the output of running the first, then the second from its store. |
| PAT-FREEINTERPRETER-02 | free_interpreter | A `get` right after a `put` of the same key reads the value put. |
| PAT-FREEINTERPRETER-03 | free_interpreter | For any start store, running `ensureDefault` twice equals running it once. |
| PAT-FREEINTERPRETER-04 | free_interpreter | For any program, `simplify` leaves the pure interpreter's store and output unchanged. |
| PAT-FREEINTERPRETER-05 | free_interpreter | `simplify` is idempotent and never longer; of consecutive writes to one key only the last remains, and a write separated by a read is kept. |
| PAT-FREEINTERPRETER-06 | free_interpreter | An interpreter that mutates a table gives the same output and final store as the pure interpreter on any program. |
| PAT-FREEINTERPRETER-07 | free_interpreter | `pretty` prints one line per instruction (bodies included, indented under their guard) and the same text every time. |
| PAT-TAGLESSFINAL-01 | tagless_final | `dotProduct` and `horner` interpreted as `Eval` equal plain arithmetic. |
| PAT-TAGLESSFINAL-02 | tagless_final | Interpreted as `Size`, `dotProduct` of n pairs has 1 + 4n nodes and `horner` of n + 1 coefficients has 1 + 4n. |
| PAT-TAGLESSFINAL-03 | tagless_final | Reifying a program to an `Ast` and evaluating or counting the tree equals the direct `Eval` and `Size` interpretations. |
| PAT-TAGLESSFINAL-04 | tagless_final | The `Show` interpretation equals the printed reified tree, has balanced parentheses, and shows `((0+(2*3))+(4*-1))` for the pairs (2,3), (4,-1). |
| PAT-TAGLESSFINAL-05 | tagless_final | `negated` evaluates to the negation of `dotProduct` and has exactly one more node. |
| PAT-DEPENDENCYRECORD-01 | dependency_record | With recording fakes, `remindOverdue` sends one message per unpaid invoice due before today, in list order, to its customer with the documented body, and returns the sender's ids. |
| PAT-DEPENDENCYRECORD-02 | dependency_record | When the sender fails on its kth call, a `RemindError` is returned with the sender's reason and the ids of the k - 1 messages already sent, and no later invoice is tried. |
| PAT-DEPENDENCYRECORD-03 | dependency_record | `withClock` replaces only the clock; paid invoices, and invoices not yet due under the clock, are never sent. |
| PAT-DEPENDENCYRECORD-04 | dependency_record | The same invoices and equivalent fakes give equal results and equal messages on every run. |
| PAT-TIMEASINPUT-01 | time_as_input | For any sender and `Now`, moving only the wall clock (`wallJumped`) by any amount changes neither `decide` nor the `retryAt` a failed `sent` sets. |
| PAT-TIMEASINPUT-02 | time_as_input | With a pending change and no wait running, `decide` is `acSend` exactly when the monotonic time since the last change is at least `quiet`; with nothing pending it is `acWait`. |
| PAT-TIMEASINPUT-03 | time_as_input | After a failed send at `t`, the change stays pending and `decide` is `acSend` exactly when at least `retryAfter` has passed since `t`. |
| PAT-TIMEASINPUT-04 | time_as_input | A successful send clears what was pending except a change made after the `Now` it was decided at; the same inputs give the same decision; `stamp` is the wall clock of the same reading. |
| PAT-TIMEASINPUT-05 | time_as_input | `initSendPolicy` rejects a span that is not positive; `(t + d) - t == d`; the policy's fields are not readable outside the module, and wall and monotonic times neither subtract nor compare with each other. |
| PAT-ATOMICPUBLISH-01 | atomic_publish | For any old content (or none), new content, crash point, torn write and lost rename, the visible name holds exactly the old or exactly the new content, in the full mode and in the mode without the directory fsync. |
| PAT-ATOMICPUBLISH-02 | atomic_publish | While the protocol runs and nothing crashes, the visible name holds the old content until the rename step and the new content from it; the temporary name is a prefixed name in the same directory and never the visible name. |
| PAT-ATOMICPUBLISH-03 | atomic_publish | After a finished full publish, any crash leaves the new content; without the directory fsync a crash can bring back the old content, and without any fsync a search finds a crash that leaves the visible name empty or cut. |
| PAT-ATOMICPUBLISH-04 | atomic_publish | After a stop at any step, `leftovers` are exactly the names with the temporary prefix, `cleanup` removes exactly them, durably (a later stop does not bring them back), and is idempotent, and a finished publish leaves none. |
| PAT-ATOMICPUBLISH-05 | atomic_publish | Publishing the same content twice (with different tokens) gives the same directory as publishing it once, with no temporary file left. |
| PAT-ATOMICPUBLISH-06 | atomic_publish | `publishPlan` gives the steps in protocol order for each mode, names the temporary file in the target's directory and unique per token, and refuses a target that is empty, has a separator, is `.` or `..` or has the temporary prefix, and a token that is not a plain name. |
| PAT-ATOMICPUBLISH-07 | atomic_publish | With the visible name the hash of the content, any crash leaves either no such name or one whose content verifies; a second publication changes nothing; a cut file under a hash name fails `verifies`. |
| PAT-ATOMICPUBLISH-08 | atomic_publish | `publishFile` leaves a file holding exactly the content (empty and 1 MiB included) and no temporary file, replaces an existing file, and returns `peDirMissing` or `peBadTarget` as values instead of raising. |
| PAT-PIPELINE-01 | pipeline | The identity middleware leaves a handler's answer to every request unchanged. |
| PAT-PIPELINE-02 | pipeline | `andThen` is associative: either grouping of three stacks answers every request the same way. |
| PAT-PIPELINE-03 | pipeline | `identity` is a left and right unit of `andThen`. |
| PAT-PIPELINE-04 | pipeline | `requireUser` refuses a request without a user with 401 whatever lies behind it; `limitBody` refuses a longer body with 413 and passes one at the limit. |
| PAT-PIPELINE-05 | pipeline | In `compose`, the first middleware is outermost: tags appear in list order before the handler's body. |
| PAT-PIPELINE-06 | pipeline | `compose(xs & ys)` behaves as `andThen(compose(xs), compose(ys))`, and `compose` of the empty list behaves as `identity`. |
| PAT-IDEMPOTENTCOMMAND-01 | idempotent_command | Handling the same command twice gives the same ledger and the same response as handling it once. |
| PAT-IDEMPOTENTCOMMAND-02 | idempotent_command | For any at-least-once delivery (each command at least once, duplicates after the first arrival), the final ledger equals exactly-once processing. |
| PAT-IDEMPOTENTCOMMAND-03 | idempotent_command | A redelivered command gets the response of its first handling, even after later commands changed the balance, and the ledger does not change. |
| PAT-IDEMPOTENTCOMMAND-04 | idempotent_command | For commands with distinct keys, the balance equals an independent model and the ledger holds one entry per key. |
| PAT-IDEMPOTENTCOMMAND-05 | idempotent_command | A different command under a used key answers `rkKeyConflict` and leaves the ledger unchanged. |
| PAT-IDEMPOTENTCOMMAND-06 | idempotent_command | A non-positive amount is refused (`rkInvalidAmount`), keeps the balance and is refused identically on retry; a withdrawal beyond the balance is `rkInsufficientFunds`. |
| PAT-LENS-01 | lens | Get-set: putting back the value just viewed returns an equal whole, for primitive and composed lenses. |
| PAT-LENS-02 | lens | Set-get: viewing after a put returns the value put; a lens whose setter clamps its input breaks this and the property finds a counterexample. |
| PAT-LENS-03 | lens | Set-set: two puts in turn equal the second put alone. |
| PAT-LENS-04 | lens | `compose` is associative in behaviour: both groupings of three lenses give the same view and the same put. |
| PAT-LENS-05 | lens | `over(l, s, f)` equals `put(l, s, f(view(l, s)))`; `over` with the identity changes nothing; two `over`s equal one `over` of the composed functions. |
| PAT-LENS-06 | lens | A put through a composed lens changes only the focused field and leaves the original value intact. |
| PAT-RETRYBACKOFF-01 | retry_backoff | For any valid policy, failure count below `maxAttempts` and jitter, the delay is at most the cap and at least `min(base, cap)`. |
| PAT-RETRYBACKOFF-02 | retry_backoff | For any policy and any sequence of jitter values, delays by attempt never decrease. |
| PAT-RETRYBACKOFF-03 | retry_backoff | `nextDelay` gives up exactly when failures reach `maxAttempts`; `schedule` has `maxAttempts - 1` delays. |
| PAT-RETRYBACKOFF-04 | retry_backoff | With zero jitter (percentage or sample), the delay is the base doubled per failure and cut at the cap. |
| PAT-RETRYBACKOFF-05 | retry_backoff | `jitterFor` is deterministic and always in 0..999, and `schedule` is equal for equal seeds. |
| PAT-RETRYBACKOFF-06 | retry_backoff | `initPolicy` reports a distinct error for each out-of-range parameter and a valid policy reports exactly its parameters. |
| PAT-RETRYBACKOFF-07 | retry_backoff | For any seed (up to 2^63) and any pattern of call outcomes, `simulate` makes as many calls as the first success (capped at `maxAttempts`), reports success exactly when that success is within the cap, and sleeps the prefix of the schedule; an imperative shell makes the same calls and sleeps the same waits. |
| PAT-PARSERCOMBINATOR-01 | parser_combinator | For any expression tree, `parseArithmetic(print(e))` returns a tree equal to `e`. |
| PAT-PARSERCOMBINATOR-02 | parser_combinator | Parsing text honours precedence and left associativity: `a-b-c`, `a+b*c`, `a*b+c`, `a-b+c` and `(a+b)*c` evaluate as host arithmetic does. |
| PAT-PARSERCOMBINATOR-03 | parser_combinator | For arbitrary text the answer is a value: an error whose position lies in the text, or a tree that reprints and reparses to itself; a valid expression followed by junk is an error at the junk; empty, truncated and over-long numbers are errors; when every alternative fails at the same position the error lists the expectations joined with "or" and otherwise reports the one that got further. |
| PAT-PARSERCOMBINATOR-04 | parser_combinator | `many(digit())` always succeeds and consumes exactly the leading digits; `orElse(p, q)` equals `p` wherever `p` succeeds and falls back to `q` otherwise. |
| PAT-PARSERCOMBINATOR-05 | parser_combinator | For any tree, `printSpaced` output, with extra blanks around it, parses back to the same tree. |
| PAT-PARSERCOMBINATOR-07 | parser_combinator | Input longer than `MaxInputLen` (1024 bytes) or nested deeper than `MaxNesting` (64 parentheses) is refused with a `ParseError` before parsing, never a crash; input at the limits parses, prints, compares and evaluates. |
| PAT-PARSERCOMBINATOR-06 | parser_combinator | For small expressions, print, parse and evaluate equals an independent stack model; an intermediate value beyond 2^31 is `eeOutOfRange`. |
