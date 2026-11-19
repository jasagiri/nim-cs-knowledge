## Idempotence: doing it twice is the same as doing it once (ADR-NCK-0002 S4, S6).
##
## An operation `f` is idempotent when `f(f(x)) == f(x)` for every `x`. That is what makes a retry
## safe: a client that does not know whether its request arrived can send it again. This module
## holds four small idempotent operations and the law checker they share:
## `normalizeSpaces` (a normal form), `setInsert` (add to a sorted set), `upsertByKey` (insert or
## replace by key), and `apply` on a `Ledger` (a state transition guarded by an idempotency key,
## "apply this command at most once", where a reused key with a different command is an error).
## Every state is a value; nothing is mutated in place.

import std/algorithm
import nimcs/fp/result

func isIdempotentAt*[T](f: proc(x: T): T {.noSideEffect, raises: [].}; x: T): bool {.raises: [].} =
  ## True when `f(f(x)) == f(x)`. Use it as the body of a property test.
  f(f(x)) == f(x)

func normalizeSpaces*(s: string): string {.raises: [].} =
  ## Removes leading and trailing spaces and turns every run of spaces into a single space.
  var pendingSpace = false
  for c in s:
    if c == ' ':
      pendingSpace = result.len > 0
    else:
      if pendingSpace:
        result.add ' '
        pendingSpace = false
      result.add c

func setInsert*(xs: seq[int]; x: int): seq[int] {.raises: [].} =
  ## `xs` must be sorted and without duplicates; the result is too, and contains `x` exactly once.
  let at = xs.lowerBound(x)
  if at < xs.len and xs[at] == x:
    return xs
  result = xs[0 ..< at]
  result.add x
  result.add xs[at .. ^1]

type
  Entry* = object
    key*: string
    value*: int

func upsertByKey*(entries: seq[Entry]; key: string; value: int): seq[Entry] {.raises: [].} =
  ## Sets the value of `key`: the first entry with that key takes `value`, any further entries
  ## with the same key are dropped, and a missing key is appended. The result has exactly one
  ## entry for `key` even when the input had duplicates; other keys keep their order.
  result = newSeqOfCap[Entry](entries.len + 1)
  var found = false
  for e in entries:
    if e.key != key:
      result.add e
    elif not found:
      result.add Entry(key: key, value: value)
      found = true
  if not found:
    result.add Entry(key: key, value: value)

type
  Command* = object
    key*: string      ## idempotency key: a retry of the same request carries the same key
    amount*: int

  Ledger* = object
    ## The balance and, for each key already applied, the command that was applied.
    balance*: int
    applied*: seq[Command]   ## sorted by key, one command per key

  ApplyError* = enum
    keyConflict   ## the key was used before for a different command: a client bug, not a retry

func initLedger*(): Ledger {.raises: [].} =
  Ledger(balance: 0, applied: @[])

func `==`*(a, b: Command): bool {.raises: [].} =
  a.key == b.key and a.amount == b.amount

func `==`*(a, b: Ledger): bool {.raises: [].} =
  a.balance == b.balance and a.applied == b.applied

func findKey(l: Ledger; key: string): int {.raises: [].} =
  ## Index of the first applied command whose key is not below `key` (binary search).
  var lo = 0
  var hi = l.applied.len
  while lo < hi:
    let mid = (lo + hi) div 2
    if l.applied[mid].key < key: lo = mid + 1 else: hi = mid
  lo

func hasApplied*(l: Ledger; key: string): bool {.raises: [].} =
  let at = l.findKey(key)
  at < l.applied.len and l.applied[at].key == key

func apply*(l: Ledger; c: Command): Result[Ledger, ApplyError] {.raises: [].} =
  ## Adds `c.amount` to the balance the first time `c.key` is seen. The same command again
  ## (same key, same amount) is a retry and returns the same ledger. The same key with a
  ## different amount is `keyConflict`: it is reported, never silently ignored.
  ## Precondition: the balance stays within `int`.
  let at = l.findKey(c.key)
  if at < l.applied.len and l.applied[at].key == c.key:
    if l.applied[at] == c: return ok(l, ApplyError)
    return err(Ledger, keyConflict)
  var next = Ledger(balance: l.balance + c.amount, applied: l.applied[0 ..< at])
  next.applied.add c
  next.applied.add l.applied[at .. ^1]
  ok(next, ApplyError)

func applyAll*(l: Ledger; commands: openArray[Command]): Result[Ledger, ApplyError] {.raises: [].} =
  ## Applies the commands in order and stops at the first conflict.
  var cur = l
  for c in commands:
    let r = cur.apply(c)
    if r.isErr:
      return r
    cur = r.value
  ok(cur, ApplyError)
