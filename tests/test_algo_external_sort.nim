import std/[algorithm, unittest]
import propcheck
import nimcs/fp/result
import nimcs/algo/external_sort

proc datas(): Gen[seq[int]] {.raises: [ValueError].} =
  seqOf(intIn(-20, 20), 0, 40)

func runsOf(data: seq[int]; memory: int): seq[Run] {.raises: [].} =
  ## The memory used by the tests is always at least 1, so run formation cannot fail.
  formRuns(data, memory).value

# SPEC: EXTSORT-SORT-01
test "EXTSORT-SORT-01 Given a hand-worked input, when sorting with small memory, then the sorted list and cost come back":
  let r = externalSort(@[5, 3, 9, 1, 7, 2, 8], 3, 2).value
  check r.items == @[1, 2, 3, 5, 7, 8, 9]
  # runs: [3,5,9] [1,2,7] [8] -> 3 runs -> 2 runs -> 1 run: two merge passes
  check r.cost == IoCost(mergePasses: 2, reads: 21, writes: 21)

# SPEC: EXTSORT-SORT-01
test "EXTSORT-SORT-01 Given any data, memory and fan-in, when sorting, then the result equals the in-memory sort":
  let outcome = check(pair(datas(), pair(intIn(1, 9), intIn(2, 6))),
                      proc(p: (seq[int], (int, int))): bool {.raises: [CatchableError].} =
    externalSort(p[0], p[1][0], p[1][1]).value.items == p[0].sorted)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: EXTSORT-SORT-02
test "EXTSORT-SORT-02 Given sorted output, when sorting it again, then the items are unchanged":
  let outcome = check(pair(datas(), pair(intIn(1, 9), intIn(2, 6))),
                      proc(p: (seq[int], (int, int))): bool {.raises: [CatchableError].} =
    let once = externalSort(p[0], p[1][0], p[1][1]).value.items
    externalSort(once, p[1][0], p[1][1]).value.items == once)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: EXTSORT-SORT-03
test "EXTSORT-SORT-03 Given empty data, memory that holds everything, or invalid parameters, when sorting, then the edge cases behave":
  check externalSort(newSeq[int](), 4, 2).value == Sorted(items: @[], cost: IoCost())
  let single = externalSort(@[3, 1, 2], 10, 2).value
  check single.items == @[1, 2, 3]
  check single.cost == IoCost(mergePasses: 0, reads: 3, writes: 3)
  check externalSort(@[1], 0, 2).error == eeBadMemory
  check externalSort(@[1], 2, 1).error == eeBadFanIn
  check formRuns(@[1], -1).error == eeBadMemory

# SPEC: EXTSORT-RUNS-01
test "EXTSORT-RUNS-01 Given any data and memory, when forming runs, then there are ceil(n / memory) runs, each sorted and non-empty":
  let outcome = check(pair(datas(), intIn(1, 9)), proc(p: (seq[int], int)): bool {.raises: [CatchableError].} =
    let runs = runsOf(p[0], p[1])
    var ok = runs.len == (p[0].len + p[1] - 1) div p[1]
    for run in runs:
      ok = ok and run.len >= 1 and run.len <= p[1] and run.isSorted
    ok)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: EXTSORT-RUNS-02
test "EXTSORT-RUNS-02 Given any data and memory, when forming runs, then together they hold exactly the input items":
  let outcome = check(pair(datas(), intIn(1, 9)), proc(p: (seq[int], int)): bool {.raises: [CatchableError].} =
    var all: seq[int]
    for run in runsOf(p[0], p[1]):
      all.add run
    all.sorted == p[0].sorted)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: EXTSORT-MERGE-01
test "EXTSORT-MERGE-01 Given any sorted runs, when merging, then the result is the sorted concatenation":
  let outcome = check(pair(datas(), intIn(1, 6)), proc(p: (seq[int], int)): bool {.raises: [CatchableError].} =
    let runs = runsOf(p[0], p[1])
    let merged = mergeRuns(runs)
    var all: seq[int]
    for run in runs:
      all.add run
    merged == all.sorted)
  checkpoint describe(outcome)
  check outcome.passed
  check mergeRuns(newSeq[Run]()) == newSeq[int]()
  check mergeRuns(@[@[1, 4], newSeq[int](), @[2, 3]]) == @[1, 2, 3, 4]

# SPEC: EXTSORT-COST-01
test "EXTSORT-COST-01 Given any data, memory and fan-in, when sorting, then the counted passes and I/O equal the closed form":
  let outcome = check(pair(datas(), pair(intIn(1, 9), intIn(2, 6))),
                      proc(p: (seq[int], (int, int))): bool {.raises: [CatchableError].} =
    let data = p[0]
    let (memory, fanIn) = p[1]
    let cost = externalSort(data, memory, fanIn).value.cost
    let runs = (data.len + memory - 1) div memory
    # The reference counts ceil(log_fanIn runs) as the least p with fanIn^p >= runs.
    var power = 1
    var passes = 0
    while power < runs:
      power *= fanIn
      inc passes
    cost.mergePasses == passes and passes == expectedMergePasses(runs, fanIn) and
      cost.reads == data.len * (1 + passes) and cost.writes == cost.reads)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: EXTSORT-COST-02
test "EXTSORT-COST-02 Given a larger fan-in, when sorting the same data, then the pass count never rises":
  let outcome = check(pair(datas(), intIn(1, 5)), proc(p: (seq[int], int)): bool {.raises: [CatchableError].} =
    var last = high(int)
    var ok = true
    for fanIn in 2 .. 8:
      let passes = externalSort(p[0], p[1], fanIn).value.cost.mergePasses
      ok = ok and passes <= last
      last = passes
    ok)
  checkpoint describe(outcome)
  check outcome.passed
  check expectedMergePasses(1, 2) == 0
  check expectedMergePasses(0, 2) == 0
  check expectedMergePasses(1000, 10) == 3
  check expectedMergePasses(1001, 10) == 4
