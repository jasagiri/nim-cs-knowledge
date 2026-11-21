## Bulkhead: a fixed number of permits per compartment, so one partition's load cannot take another's capacity.
##
## A ship's bulkheads keep a flooded compartment from sinking the rest. In a service, one shared pool
## of workers lets a slow tenant or a slow dependency hold every worker; giving each partition its
## own number of permits keeps the damage inside the partition. The whole state is one value,
## `Bulkhead`: the permit limit and the permits in use of every compartment. `tryAcquire` is a pure
## admission function that returns the new value and the answer; `release` returns a permit and
## refuses to release one that was never taken, so a double release cannot grow the capacity.
## Nothing here blocks or waits: a refusal is a value, and what to do with it (queue, shed, fail
## fast) belongs to the caller, see `load_shedding` for deciding by queue length and deadline.
## Use it around calls that share a scarce resource and can be grouped by tenant, dependency or
## priority class.

import std/[tables, algorithm]
import nimcs/fp/result
export result

type
  Bulkhead* = object
    limits: Table[string, int]
    inUse: Table[string, int]

  Admission* = enum
    aAdmitted, aFull, aUnknownCompartment

  SetupError* = enum
    seNoCompartments, seEmptyName, seDuplicateName, seLimitNotPositive

  ReleaseError* = enum
    reUnknownCompartment, reNothingToRelease

func `==`*(a, b: Bulkhead): bool {.raises: [].} = a.limits == b.limits and a.inUse == b.inUse

func initBulkhead*(limits: openArray[(string, int)]): Result[Bulkhead, SetupError] {.raises: [].} =
  ## One `(name, permits)` pair per compartment. Names are non-empty and distinct, permits are
  ## positive, and there is at least one compartment; the first violated rule is reported.
  if limits.len == 0:
    return err(Bulkhead, seNoCompartments)
  var table = initTable[string, int]()
  var used = initTable[string, int]()
  for (name, permits) in limits:
    if name.len == 0: return err(Bulkhead, seEmptyName)
    if table.hasKey(name): return err(Bulkhead, seDuplicateName)
    if permits < 1: return err(Bulkhead, seLimitNotPositive)
    table[name] = permits
    used[name] = 0
  ok(Bulkhead(limits: table, inUse: used), SetupError)

func limit*(b: Bulkhead; compartment: string): int {.raises: [].} =
  ## The permits of a compartment; 0 for an unknown name.
  b.limits.getOrDefault(compartment, 0)

func inUse*(b: Bulkhead; compartment: string): int {.raises: [].} =
  ## The permits taken now; 0 for an unknown name.
  b.inUse.getOrDefault(compartment, 0)

func available*(b: Bulkhead; compartment: string): int {.raises: [].} =
  b.limit(compartment) - b.inUse(compartment)

func usage*(b: Bulkhead): seq[(string, int)] {.raises: [].} =
  ## `(name, permits in use)` for every compartment, sorted by name (the table's own order is not
  ## part of the contract and never leaks).
  for name, n in b.inUse:
    result.add (name, n)
  result.sort(proc(x, y: (string, int)): int = cmp(x[0], y[0]))

func tryAcquire*(b: Bulkhead; compartment: string): tuple[bulkhead: Bulkhead, admission: Admission] {.raises: [].} =
  ## Take one permit of `compartment` when one is free. A refusal returns the bulkhead unchanged.
  if not b.limits.hasKey(compartment):
    return (b, aUnknownCompartment)
  if b.inUse(compartment) >= b.limit(compartment):
    return (b, aFull)
  var next = b
  next.inUse[compartment] = b.inUse(compartment) + 1
  (next, aAdmitted)

func release*(b: Bulkhead; compartment: string): Result[Bulkhead, ReleaseError] {.raises: [].} =
  ## Give back one permit. Releasing in a compartment with no permit taken is an error, not a
  ## no-op: it would mean some caller releases twice, and the capacity would silently grow.
  if not b.limits.hasKey(compartment):
    return err(Bulkhead, reUnknownCompartment)
  if b.inUse(compartment) < 1:
    return err(Bulkhead, reNothingToRelease)
  var next = b
  next.inUse[compartment] = b.inUse(compartment) - 1
  ok(next, ReleaseError)
