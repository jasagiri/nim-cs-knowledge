## Parallel change (expand, migrate, contract): change a shape without a moment when callers break.
##
## A change to something many callers use (a column, a field, a function's argument) is done in
## three steps that each leave every caller working: expand (the new shape exists next to the old
## one and every writer keeps both in step), migrate (fill the new shape for data written before,
## move callers one at a time) and contract (remove the old shape once nothing reads it). Here a
## person's name moves from one legacy text, "Family, Given", to a `Name` with two parts. A record
## holds both columns; writers through either door set both, readers fall back to translating the
## other column, `backfill` fills rows that predate the change, and `contract` is a function that
## refuses to drop the legacy column while any row would lose its only copy. Use it when callers
## cannot all be changed in one commit or one deploy; it costs a period with two shapes, so give the
## period an end.

import std/options
import nimcs/fp/result
export result

type
  NameError* = enum
    neEmptyGiven, neEmptyFamily, neComma, neNoSeparator

  Name* = object
    given*, family*: string

  Record* = object
    ## During expand both fields may be set. A row written before the change has only `legacy`;
    ## after contract only `current` is set.
    legacy*: Option[string]
    current*: Option[Name]

  Store* = seq[Record]

  ContractError* = object
    firstUnmigrated*: int   ## index of the first row with no current name

const Separator = ", "

func initName*(given, family: string): Result[Name, NameError] {.raises: [].} =
  ## A part may be neither empty nor contain a comma, so the legacy text splits back uniquely.
  if given.len == 0:
    err(Name, neEmptyGiven)
  elif family.len == 0:
    err(Name, neEmptyFamily)
  elif ',' in given or ',' in family:
    err(Name, neComma)
  else:
    ok(Name(given: given, family: family), NameError)

func formatLegacy*(n: Name): string {.raises: [].} = n.family & Separator & n.given

func parseLegacy*(s: string): Result[Name, NameError] {.raises: [].} =
  ## Splits at the first separator; every other shape is an error, never an exception.
  var at = -1
  for i in 0 ..< s.len - 1:
    if s[i] == ',' and s[i + 1] == ' ':
      at = i
      break
  if at < 0:
    err(Name, neNoSeparator)
  else:
    initName(s[at + Separator.len .. ^1], s[0 ..< at])

func writeCurrent*(n: Name): Record {.raises: [].} =
  ## The new door keeps the old column in step so legacy readers stay right.
  Record(legacy: some(formatLegacy(n)), current: some(n))

func writeLegacy*(s: string): Result[Record, NameError] {.raises: [].} =
  ## The old door keeps the new column in step; a text that does not parse is refused here, not
  ## stored where only one reader could use it.
  let parsed = parseLegacy(s)
  if parsed.isOk:
    ok(Record(legacy: some(s), current: some(parsed.value)), NameError)
  else:
    err(Record, parsed.error)

func readCurrent*(r: Record): Option[Name] {.raises: [].} =
  if r.current.isSome:
    r.current
  elif r.legacy.isSome:
    let parsed = parseLegacy(r.legacy.get)
    if parsed.isOk: some(parsed.value) else: none(Name)
  else:
    none(Name)

func readLegacy*(r: Record): Option[string] {.raises: [].} =
  ## Kept after contract only to show that an old caller would still get the same answer.
  if r.legacy.isSome:
    r.legacy
  elif r.current.isSome:
    some(formatLegacy(r.current.get))
  else:
    none(string)

func backfill*(r: Record): Record {.raises: [].} =
  ## Fills the current name of a row written before the change. Idempotent; a text that does not
  ## parse stays as it is, for a person to look at.
  if r.current.isNone:
    Record(legacy: r.legacy, current: readCurrent(r))
  else:
    r

func contract*(s: Store): Result[Store, ContractError] {.raises: [].} =
  ## Drops the legacy column, but only when no row would lose its only copy of the name.
  for i, r in s:
    if r.current.isNone:
      return err(Store, ContractError(firstUnmigrated: i))
  var done: Store = @[]
  for r in s:
    done.add Record(legacy: none(string), current: r.current)
  ok(done, ContractError)
