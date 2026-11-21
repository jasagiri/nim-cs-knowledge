# Specification: data structures (DS), part e

Each row is a law or an externally visible behaviour; each ID has at least one tagged test in `tests/test_ds_<concept>.nim`.

| ID | Concept | Statement |
|---|---|---|
| DS-WRITEAHEADLOG-01 | write_ahead_log | Given a log, when appending payloads, then they get sequence numbers 0, 1, 2 in order and the old log is unchanged |
| DS-WRITEAHEADLOG-02 | write_ahead_log | Given a log, when replaying, then the state is the left fold of apply over the payloads and the empty log gives the initial state |
| DS-WRITEAHEADLOG-03 | write_ahead_log | Given any log, when encoded and recovered, then the same log comes back with nothing dropped |
| DS-WRITEAHEADLOG-04 | write_ahead_log | Given an encoded log cut at any byte, when recovering, then exactly the records wholly before the cut are kept and the rest is dropped |
| DS-WRITEAHEADLOG-05 | write_ahead_log | Given an encoded log, when any one byte is changed, then recovery keeps exactly the records before the damaged one |
| DS-WRITEAHEADLOG-06 | write_ahead_log | Given arbitrary bytes, when recovering, then it never fails and the recovered log encodes to the kept prefix |
| DS-WRITEAHEADLOG-07 | write_ahead_log | Given a log with a torn tail, when recovering twice and replaying twice, then every step gives the same log and the same state |
| DS-WRITEAHEADLOG-08 | write_ahead_log | Given known inputs, when computing crc32, then the standard check values come out |
| DS-WRITEAHEADLOG-09 | write_ahead_log | Given a payload over the limit or a length field larger than the bytes left, then append refuses it and recover stops without reading past the end |
| DS-CONSISTENTHASHING-01 | consistent_hashing | Given a ring, when asking for an owner, then an empty ring has none and otherwise the owner is a member and is always the same |
| DS-CONSISTENTHASHING-02 | consistent_hashing | Given nodes added in any order or more than once, when comparing rings, then the ring is the same |
| DS-CONSISTENTHASHING-03 | consistent_hashing | Given a ring and a new node, when it is added, then the keys that move are exactly the keys the new node owns and no key moves between old nodes |
| DS-CONSISTENTHASHING-04 | consistent_hashing | Given a ring, when a node is removed, then only the keys it owned move, and removing an absent node or re-adding the node changes nothing else |
| DS-CONSISTENTHASHING-05 | consistent_hashing | Given a ring, when asking for n owners, then they are distinct, start with the owner, and number min(n, nodes) |
| DS-CONSISTENTHASHING-06 | consistent_hashing | Given fixed strings, when hashing, then the values are the pinned ones (the same on every run and platform) |
| DS-CONSISTENTHASHING-07 | consistent_hashing | Given four nodes with 128 virtual nodes each and 4000 keys, when a fifth node is added, then every node holds 20 to 30 percent and about a fifth of the keys move, where hash mod n moves most |
| DS-CONSISTENTHASHING-08 | consistent_hashing | Given bad arguments, when building, then a ring needs at least one virtual node and a node needs a name |
| DS-CRDT-01 | crdt | Given an empty name, when making a replica id, then it is refused |
| DS-CRDT-02 | crdt | Given counters that each replica changed on its own copy, when merged, then the value is the total of all increments and each replica keeps its own count |
| DS-CRDT-03 | crdt | Given any two G-Counters, when merged either way round, then the results are equal |
| DS-CRDT-04 | crdt | Given any three G-Counters, when merged in either grouping, then the results are equal |
| DS-CRDT-05 | crdt | Given any G-Counters, when merging a state again, then nothing changes |
| DS-CRDT-06 | crdt | Given several G-Counters, when merged in any order and grouping, then the result is the same |
| DS-CRDT-07 | crdt | Given a G-Counter, when merging or incrementing, then the value never goes down |
| DS-CRDT-08 | crdt | Given PN-Counters changed on separate copies, when merged, then the value is all increments minus all decrements |
| DS-CRDT-09 | crdt | Given any two PN-Counters, when merged either way round, then the results are equal |
| DS-CRDT-10 | crdt | Given any three PN-Counters, when merged in either grouping, then the results are equal |
| DS-CRDT-11 | crdt | Given any PN-Counters, when merging a state again, then nothing changes |
| DS-CRDT-12 | crdt | Given several PN-Counters, when merged in any order and grouping, then the result is the same |
| DS-CRDT-13 | crdt | Given writes, when merged, then the winner is the one with the largest stamp, then replica id, then value, and an empty register loses |
| DS-CRDT-14 | crdt | Given any two LWW-Registers, when merged either way round, then the results are equal |
| DS-CRDT-15 | crdt | Given any three LWW-Registers, when merged in either grouping, then the results are equal |
| DS-CRDT-16 | crdt | Given any LWW-Registers, when merging a state again, then nothing changes |
| DS-CRDT-17 | crdt | Given several LWW-Registers, when merged in any order and grouping, then the result is the same |
| DS-CRDT-18 | crdt | Given an OR-Set, when adding and removing, then remove cancels only the additions it has seen and a concurrent add wins |
| DS-CRDT-19 | crdt | Given one replica's adds and removes, when compared with a set model, then the elements agree at every step |
| DS-CRDT-20 | crdt | Given any two OR-Sets, when merged either way round, then the results are equal |
| DS-CRDT-21 | crdt | Given any three OR-Sets, when merged in either grouping, then the results are equal |
| DS-CRDT-22 | crdt | Given any OR-Sets, when merging a state again, then nothing changes |
| DS-CRDT-23 | crdt | Given several OR-Sets, when merged in any order and grouping, then the result is the same |
