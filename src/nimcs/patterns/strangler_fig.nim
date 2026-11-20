## Strangler fig: replace a system one route at a time while the old one keeps answering.
##
## A rewrite that must be switched on in one step cannot be tried, undone or finished early. The
## strangler fig grows around the old system instead: a front door holds a table from request
## prefixes to the system that answers them, everything the table does not name still goes to the
## old system, and each step moves one prefix to the new one. The table is a value, so moving a
## prefix, moving it back, and asking whether the old system can be switched off are functions
## with laws. The observable answer changes only when the two systems disagree on a request, and
## then only for requests that follow the moved prefix. Use it when users cannot wait for a
## rewrite to be whole; it needs one front door that sees every request, and it does not by
## itself make the two systems agree (that is for tests that run both on the same requests).

import std/strutils
import nimcs/fp/result
export result

type
  Target* = enum
    tgLegacy, tgModern

  TableError* = enum
    teEmptyPrefix

  Route* = tuple[prefix: string, target: Target]

  Table* = object
    entries*: seq[Route]   ## one entry per prefix, in the order the prefixes were first named
    fallback*: Target      ## where a request goes when no prefix matches

  System* = proc(request: string): string {.noSideEffect, raises: [].}

func initTable*(): Table {.raises: [].} =
  ## Everything goes to the old system until a prefix is moved.
  Table(entries: @[], fallback: tgLegacy)

func withRoute*(t: Table; prefix: string; target: Target): Result[Table, TableError] {.raises: [].} =
  ## Names a prefix; naming it again replaces its target, so the call is idempotent.
  if prefix.len == 0:
    return err(Table, teEmptyPrefix)
  var entries = t.entries
  var found = false
  for e in entries.mitems:
    if e.prefix == prefix:
      e.target = target
      found = true
  if not found:
    entries.add (prefix: prefix, target: target)
  ok(Table(entries: entries, fallback: t.fallback), TableError)

func strangle*(t: Table; prefix: string): Result[Table, TableError] {.raises: [].} =
  withRoute(t, prefix, tgModern)

func retreat*(t: Table; prefix: string): Result[Table, TableError] {.raises: [].} =
  ## The way back from `strangle`: the prefix names the old system again.
  withRoute(t, prefix, tgLegacy)

func withFallback*(t: Table; target: Target): Table {.raises: [].} =
  Table(entries: t.entries, fallback: target)

func route*(t: Table; request: string): Target {.raises: [].} =
  ## The longest named prefix of the request decides; the fallback when none is a prefix.
  var best = -1
  result = t.fallback
  for e in t.entries:
    if e.prefix.len > best and request.startsWith(e.prefix):
      best = e.prefix.len
      result = e.target

func serve*(t: Table; legacy, modern: System; request: string): string {.raises: [].} =
  case t.route(request)
  of tgLegacy: legacy(request)
  of tgModern: modern(request)

func isRetired*(t: Table): bool {.raises: [].} =
  ## True when no request can reach the old system, so it can be switched off.
  if t.fallback != tgModern:
    return false
  for e in t.entries:
    if e.target != tgModern:
      return false
  true
