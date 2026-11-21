## External merge sort, simulated in memory: sort data that does not fit in fast memory by
## forming sorted runs and merging them k at a time.
##
## The external store is modelled as a sequence of runs, each a sorted `seq[int]`; nothing touches
## a file. Phase 1 (run formation) reads `memory` items at a time, sorts them in memory and writes
## them back as one run, giving ceil(n / memory) runs. Phase 2 merges up to `fanIn` runs into one
## with a k-way merge driven by a small heap, pass after pass, until one run is left. Use the
## shape when the data lives on disk or across the network and the cost that matters is how often
## every item is moved, not comparisons; for data that fits in memory use `merge_sort` or
## `heap_sort`.
##
## I/O cost model (what `IoCost` counts): a pass reads each item once and writes each item once,
## so run formation costs n reads and n writes, and each merge pass costs another n reads and n
## writes. With r = ceil(n / memory) runs and fan-in k the number of merge passes is
## ceil(log_k r) (zero when r <= 1), so the total is n * (1 + passes) reads and the same number of
## writes. Items are counted, not blocks; divide by the block size B for block transfers when
## every run is stored in whole blocks.

import std/[algorithm, heapqueue]
import nimcs/fp/result

type
  ExtSortError* = enum
    eeBadMemory   ## memory must hold at least one item
    eeBadFanIn    ## the fan-in must be at least 2 (a 1-way merge never ends)

  Run* = seq[int]    ## one sorted run in the simulated external store

  IoCost* = object
    mergePasses*: int
    reads*: int      ## items read from the store, run formation included
    writes*: int     ## items written to the store, run formation included

  Sorted* = object
    items*: seq[int]
    cost*: IoCost

  Head = object
    value: int
    run: int         ## which run the value came from
    at: int          ## its index inside that run

func `<`(a, b: Head): bool {.raises: [].} =
  (a.value, a.run, a.at) < (b.value, b.run, b.at)   # the run and index only make the order total

func `==`*(a, b: IoCost): bool {.raises: [].} =
  a.mergePasses == b.mergePasses and a.reads == b.reads and a.writes == b.writes

func formRuns*(data: openArray[int]; memory: int): Result[seq[Run], ExtSortError] {.raises: [].} =
  ## Cuts `data` into consecutive chunks of at most `memory` items and sorts each one; there are
  ## ceil(len / memory) runs and no run is empty (EXTSORT-RUNS-01, EXTSORT-RUNS-02).
  if memory < 1:
    return err(seq[Run], eeBadMemory)
  var runs: seq[Run]
  var start = 0
  while start < data.len:
    let stop = min(start + memory, data.len)
    runs.add data[start ..< stop].sorted
    start = stop
  ok(runs, ExtSortError)

func mergeRuns*(runs: openArray[Run]): Run {.raises: [].} =
  ## The k-way merge of sorted runs into one sorted run: a heap holds the current head of each
  ## run and the smallest is taken, so each item costs O(log k) (EXTSORT-MERGE-01).
  var heap = initHeapQueue[Head]()
  var total = 0
  for r, run in runs:
    total += run.len
    if run.len > 0:
      heap.push Head(value: run[0], run: r, at: 0)
  result = newSeqOfCap[int](total)
  while heap.len > 0:
    let top = heap.pop
    result.add top.value
    let next = top.at + 1
    if next < runs[top.run].len:
      heap.push Head(value: runs[top.run][next], run: top.run, at: next)

func expectedMergePasses*(runCount, fanIn: int): int {.raises: [].} =
  ## ceil(log_fanIn runCount) by repeated division, the closed form of the model (EXTSORT-COST-01).
  ## Zero when there is at most one run; `fanIn` must be at least 2, otherwise the answer is 0.
  if fanIn < 2:
    return 0
  var runsLeft = runCount
  while runsLeft > 1:
    runsLeft = (runsLeft + fanIn - 1) div fanIn
    inc result

func externalSort*(data: openArray[int]; memory, fanIn: int): Result[Sorted, ExtSortError] {.raises: [].} =
  ## Sorts `data` with run formation and repeated `fanIn`-way merge passes, and reports the
  ## simulated I/O (EXTSORT-SORT-01, EXTSORT-COST-01). The result equals the in-memory sort.
  if memory < 1:
    return err(Sorted, eeBadMemory)
  if fanIn < 2:
    return err(Sorted, eeBadFanIn)
  let formed = formRuns(data, memory)
  if formed.isErr:
    return err(Sorted, formed.error)
  var runs = formed.value
  var cost = IoCost(reads: data.len, writes: data.len)
  while runs.len > 1:
    var merged: seq[Run]
    var group = 0
    while group < runs.len:
      let stop = min(group + fanIn, runs.len)
      merged.add mergeRuns(runs[group ..< stop])
      group = stop
    runs = merged
    inc cost.mergePasses
    cost.reads += data.len
    cost.writes += data.len
  let items = if runs.len == 1: runs[0] else: newSeq[int]()
  ok(Sorted(items: items, cost: cost), ExtSortError)
