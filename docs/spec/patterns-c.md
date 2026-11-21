# Specification: refactoring moves and architecture styles (PAT), part C

Modules in `src/nimcs/patterns/`; tests in `tests/test_patterns_<module>.nim`. Each row is a law or an externally visible behaviour; each ID has at least one tagged test. The refactoring rows say what stays the same while the shape changes: the before and the after are compared on generated inputs.

| ID | Concept | Statement |
|---|---|---|
| PAT-REPLACECONDITIONALWITHPOLYMORPHISM-01 | replace_conditional_with_polymorphism | For any flat parcel, the cost computed by the `if` chain `costBefore` equals the cost of the same parcel as an object variant (`toParcel`, `cost`). |
| PAT-REPLACECONDITIONALWITHPOLYMORPHISM-02 | replace_conditional_with_polymorphism | For any flat parcel, the cost computed by `costBefore` equals the cost of the same parcel as a record of procs (`toTariff`, `cost`). |
| PAT-REPLACECONDITIONALWITHPOLYMORPHISM-03 | replace_conditional_with_polymorphism | The total of a list of variant parcels is the sum of the old costs, and adding a pickup parcel does not change it. |
| PAT-REPLACECONDITIONALWITHPOLYMORPHISM-04 | replace_conditional_with_polymorphism | Known parcels cost the cents of the rate card in the variant, the record of procs and the old chain, and a negative weight costs as zero. |
| PAT-REPLACECONDITIONALWITHPOLYMORPHISM-05 | replace_conditional_with_polymorphism | A `case` over the kinds of the variant that leaves one kind out does not compile; the complete one does. |
| PAT-DECOMPOSECONDITIONAL-01 | decompose_conditional | For any visitor, `priceBefore` (one tangled condition) equals `price` (named predicates and a tier). |
| PAT-DECOMPOSECONDITIONAL-02 | decompose_conditional | A child is always free, a senior on a weekday is always free, a daytime student or an evening visitor is never at the full tier, and free takes precedence over reduced. |
| PAT-DECOMPOSECONDITIONAL-03 | decompose_conditional | On each side of every boundary of every clause (age 5/6, 65 on a weekday and at the weekend, student age 25/26 and hour 16/17, hour 19/20) the tier is the documented one. |
| PAT-DECOMPOSECONDITIONAL-04 | decompose_conditional | The price of a tier is `0` for free, the reduced price for reduced and the full price for full, in strictly increasing order. |
| PAT-EXTRACTFUNCTION-01 | extract_function | For any order, the text from the single-body `summaryBefore` equals the text from the pipeline `summary`. |
| PAT-EXTRACTFUNCTION-02 | extract_function | The subtotal of two joined lists is the sum of their subtotals, and the subtotal of the empty list is zero. |
| PAT-EXTRACTFUNCTION-03 | extract_function | The discount is zero below the threshold and a fixed percentage of the subtotal from the threshold, never more than the subtotal. |
| PAT-EXTRACTFUNCTION-04 | extract_function | For any order the parts of `summarize` add up (total = subtotal - discount + tax), the tax is that of the discounted amount, and it is rounded down. |
| PAT-EXTRACTTYPE-01 | extract_type | For two amounts in the same currency, `plus` on `Money` gives the amount and code that the loose pair of fields gave. |
| PAT-EXTRACTTYPE-02 | extract_type | Adding two currencies that differ is `meCurrencyMismatch` for `Money`, where the loose code returned the sum under the first code without notice. |
| PAT-EXTRACTTYPE-03 | extract_type | `initMoney` accepts exactly the known currency codes with a non-negative amount, and otherwise gives `meUnknownCurrency` (checked first) or `meNegative`. |
| PAT-EXTRACTTYPE-04 | extract_type | `plus` on Money of one currency is commutative and associative, and zero is its identity. |
| PAT-INTRODUCEPARAMETEROBJECT-01 | introduce_parameter_object | For any products and any arguments, `selectLoose` with six arguments gives the same list as `select` with the equivalent `Filter`. |
| PAT-INTRODUCEPARAMETEROBJECT-02 | introduce_parameter_object | Selecting with the default filter returns every product in the original order. |
| PAT-INTRODUCEPARAMETEROBJECT-03 | introduce_parameter_object | For filters without a limit, selecting with `a.narrowedBy(b)` equals selecting with `a` and then with `b`; `narrowedBy` is commutative and idempotent. |
| PAT-INTRODUCEPARAMETEROBJECT-04 | introduce_parameter_object | A filter made stricter (in stock only, a higher minimum rating) selects a subset of what the looser one selects. |
| PAT-INTRODUCEPARAMETEROBJECT-05 | introduce_parameter_object | A limit returns at most that many products, the first in list order, and a limit of zero means no limit. |
| PAT-LAYEREDARCHITECTURE-01 | layered_architecture | For any command log, the replies through the layers (`runLines`) equal those of the single tangled routine `tangledBefore`. |
| PAT-LAYEREDARCHITECTURE-02 | layered_architecture | Reading the module files, each layer imports only layers below it (the domain none, the service the domain, the shell both), and the check reports a synthetic upward or sideways import. |
| PAT-LAYEREDARCHITECTURE-03 | layered_architecture | `complete` on the domain board is idempotent, an unknown id is `deNoSuchTask`, an empty title is `deEmptyTitle`, and the old board is unchanged. |
| PAT-LAYEREDARCHITECTURE-04 | layered_architecture | Running a log in two halves, the second from the board of the first, gives the replies and final board of running the whole log. |
| PAT-LAYEREDARCHITECTURE-05 | layered_architecture | The shell, given a scripted input and an output list, writes the service's replies in order and returns its final board. |
| PAT-MODELVIEWUPDATE-01 | model_view_update | Replaying the same log twice gives the same model and the same view. |
| PAT-MODELVIEWUPDATE-02 | model_view_update | Replaying a log `b` from the model of a log `a` equals replaying `a` followed by `b`. |
| PAT-MODELVIEWUPDATE-03 | model_view_update | `trace` has one model per message plus the start, each step is `update` of the previous, and the last is the replay. |
| PAT-MODELVIEWUPDATE-04 | model_view_update | Undoing an increment or decrement returns the previous model; `reset` is idempotent and sets the count to zero. |
| PAT-MODELVIEWUPDATE-05 | model_view_update | The step stays within its range after any `setStep`, equals the request when it is in range, and undo with an empty history changes nothing. |
| PAT-LOADSHEDDING-01 | load_shedding | Deciding a request id that is already in the ledger, at any time and queue length, returns the first decision and the same ledger. |
| PAT-LOADSHEDDING-02 | load_shedding | For one request and time, a request admitted at a longer queue is admitted at every shorter queue. |
| PAT-LOADSHEDDING-03 | load_shedding | An admitted request had room in the queue, a deadline in the future, and `now + (queueLen + 1) * ticksPerItem <= deadline`. |
| PAT-LOADSHEDDING-04 | load_shedding | Whenever a low-priority request is admitted, the same request at high priority is admitted; at the soft queue length low is shed and high is not. |
| PAT-LOADSHEDDING-05 | load_shedding | Refusals name their reason in a fixed order: no id, expired, queue full, low priority shed, deadline unreachable. |
| PAT-LOADSHEDDING-06 | load_shedding | A request with no id is judged but never recorded in the ledger; limits with a soft length outside `1 .. maxQueue` or a service time below 1 are refused. |
