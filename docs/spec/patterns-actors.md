# Spec: actor and capability patterns in Nim

Modules in `src/nimcs/patterns/{actor,supervisor,request_reply,object_capability,caretaker,sealer_unsealer}.nim`; tests in `tests/test_patterns_<module>.nim`. Each row is a law or an externally visible behaviour; laws are property tests (nim-propcheck).

| ID | Concept | Statement |
|---|---|---|
| PAT-ACTOR-01 | actor | For any interleaving of messages told to several actors, the host runs them so that each actor processes its own messages in mailbox (arrival) order. |
| PAT-ACTOR-02 | actor | A mailbox is a persistent FIFO value: for any sequence, messages leave in arrival order, taking from an empty mailbox gives `none`, and earlier mailbox versions are unchanged by later posts. |
| PAT-ACTOR-03 | actor | Running the same message list twice from the same system gives equal systems (states, mailboxes, dead letters, delivery count), and `step` gives equal reactions (state and effects) for equal inputs. |
| PAT-ACTOR-04 | actor | Changing behaviour is a state change: an actor's state after any message list equals the fold of `step` over those messages, one step function handles every message, and a toggle message changes how the next message is handled. |
| PAT-ACTOR-05 | actor | A send effect puts the message in the target's mailbox; a message to a stopped or unknown address is recorded as a dead letter and never delivered. |
| PAT-ACTOR-06 | actor | A spawn effect adds an actor at the next address whose mailbox starts with the greeting; a stop effect marks the actor stopped and turns the rest of its mailbox into dead letters in order. |
| PAT-ACTOR-07 | actor | `runRounds(budget)` makes exactly `budget` deliveries when the system never goes idle, so a loop of actors answering each other cannot hang the host; a budget of 0 changes nothing. |
| PAT-SUPERVISOR-01 | supervisor | With one_for_one, a restarting exit of any child restarts exactly that child. |
| PAT-SUPERVISOR-02 | supervisor | With one_for_all, a restarting exit restarts every child in start order, except temporary siblings. |
| PAT-SUPERVISOR-03 | supervisor | With rest_for_one, a restarting exit restarts the child and the children started after it, in start order, and no earlier child. |
| PAT-SUPERVISOR-04 | supervisor | A permanent child is always restarted, a transient child only after a crash, a temporary child never; an exit that needs no restart is `dkIgnore` and returns the history unchanged. |
| PAT-SUPERVISOR-05 | supervisor | With at most N restarts within a window of T ticks, N restarts at one tick are restarted and the next within the window escalates; restarts spaced T ticks apart never escalate; with N = 0 the first restart escalates. |
| PAT-SUPERVISOR-06 | supervisor | For any crash times the returned history is ascending and has at most N entries, and an escalation names every child, in start order, as targets. |
| PAT-SUPERVISOR-07 | supervisor | `initPolicy` rejects a negative intensity, a window below 1, an empty child id and a duplicate id; `onExit` for an id not in the policy is `ueUnknownChild`; the fields of `Policy` cannot be set outside the module. |
| PAT-SUPERVISOR-08 | supervisor | The same policy, history, child, reason and tick give the same decision. |
| PAT-REQREPLY-01 | request_reply | For any mix of replies, timeouts, duplicates and unknown ids, once every request still pending is timed out, each request has settled exactly once (by reply or by timeout), with its own context, and the ledger is empty. |
| PAT-REQREPLY-02 | request_reply | A reply or a timeout for a request that already ended is dropped: it returns `none` and the ledger is unchanged. |
| PAT-REQREPLY-03 | request_reply | Correlation ids are distinct and strictly increasing, and an id is not reused after its request is settled. |
| PAT-REQREPLY-04 | request_reply | `dueAt(tick)` lists exactly the pending requests whose deadline is at most `tick`, in id order; the deadline is `now + timeout`, saturating at `high(int)`. |
| PAT-REQREPLY-05 | request_reply | `ask`, `onReply` and `onTimeout` return new ledgers; the ledger they were given is unchanged. |
| PAT-REQREPLY-06 | request_reply | A reply settles only the request whose id it carries; the other pending requests stay pending. |
| PAT-REQREPLY-07 | request_reply | A request carries the correlation id, the reply-to address and the body; `replyWith` makes a reply with the same id; the deadline is `now + timeout`. |
| PAT-OBJCAP-01 | object_capability | For any capability, any attenuation (`restrict`, `narrow`) and any path and right, the attenuated capability permits the operation only if its parent does, and its rights are a subset of the parent's; a refused attenuation is an error. |
| PAT-OBJCAP-02 | object_capability | Outside the module a `FileCap` cannot be constructed from its fields, built empty or declared without a value, and `read` and `write` cannot be called without a capability. |
| PAT-OBJCAP-03 | object_capability | A prefix capability permits only paths whose leading whole segments equal the prefix and which have at least one more segment; paths with empty, `.` or `..` segments, absolute paths and the empty path are refused; `narrow` refuses such sub-paths. |
| PAT-OBJCAP-04 | object_capability | Narrowing by `p` and then by `q` gives the same capability as narrowing by `p/q`. |
| PAT-OBJCAP-05 | object_capability | A read-only capability reads but cannot write (`ceDenied`) and leaves the store unchanged; a path outside the prefix is `ceOutside`; a write returns a new store and the earlier store is unchanged. |
| PAT-OBJCAP-06 | object_capability | A routine given a capability can use exactly what that value permits, and a copy of the value permits the same. |
| PAT-CARETAKER-01 | caretaker | Before revocation, forwarding an operation gives `ok` of the operation applied to the target. |
| PAT-CARETAKER-02 | caretaker | After revocation, forwarding any operation any number of times gives `err(crRevoked)`, and the live count drops. |
| PAT-CARETAKER-03 | caretaker | Revoking with the revoker of this caretaker once or any number of times is always `ok` and gives a caretaker that behaves the same (revoked flag, live count, forwarding result). |
| PAT-CARETAKER-04 | caretaker | A revoker revokes only its own forwarder; other forwarders of the same caretaker, including ones to an equal target, keep working. |
| PAT-CARETAKER-05 | caretaker | A forwarder of another caretaker (another brand) is refused with `crForeign`, and revoking with a revoker of another caretaker returns `err(crForeign)` and revokes nothing. |
| PAT-CARETAKER-06 | caretaker | `revoke` returns a new caretaker (inside `ok`); the caretaker value before it still forwards, and `Forwarder` and `Revoker` cannot be constructed outside the module. |
| PAT-SEALER-01 | sealer_unsealer | For the matching pair, `unseal(seal(x))` is `ok(x)` for any value. |
| PAT-SEALER-02 | sealer_unsealer | For pairs made by the same mint (pairs from different mints can share a brand, so this does not hold between them), an unsealer of any other pair gets `err(seWrongBrand)`, and the same pair opens the box. |
| PAT-SEALER-03 | sealer_unsealer | A mint started again from the same seed makes the same pairs, and consecutive pairs of one mint do not match. |
| PAT-SEALER-04 | sealer_unsealer | Outside the module a `Box`, `Sealer` or `Unsealer` cannot be constructed or its content read, a sealer cannot unseal, an unsealer cannot seal, and the content type is kept. |
