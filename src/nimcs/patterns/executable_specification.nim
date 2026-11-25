## Executable specification: each fact about a behaviour is written once, in the place a machine
## checks it.
##
## A written specification drifts from the code because nothing fails when they disagree. So the
## places split the work. The specification states the obligation, one sentence per rule, and its
## ID is what the tests must cover. The values and examples live only in the tests, as a table run
## against the code. The type carries the rule itself: a value that breaks it cannot be built. Here
## the rule is a release version `vMAJOR.MINOR.PATCH`. `Version` has private fields, so the only
## ways in are `version` and `parseVersion`. Parsing and printing are inverse laws, and `failures`
## runs a table of named examples against any function and names the ones that disagree. Use it
## when a rule has a specification that people read, so the specification, the examples and the
## code cannot say different things.

import nimcs/fp/result
export result

const MaxPart* = 999_999 ## the largest number a part may hold; six digits keep it far from overflow

type
  Version* = object
    ## A release version. Built only by `version` and `parseVersion`, so every value is valid.
    major, minor, patch: int

  VersionError* = enum
    veShape       ## not `v` and three parts of decimal digits separated by `.`
    veLeadingZero ## a part of two or more digits that starts with `0`
    veTooLarge    ## a part of more than six digits

  Example*[I, O] = tuple[name: string, input: I, expected: O]
    ## One row of an example table: the name a failure is reported by, the input and the output.

func version*(major, minor, patch: range[0 .. MaxPart]): Version {.raises: [].} =
  ## The version with these parts; the range type rejects a part out of bounds.
  Version(major: major, minor: minor, patch: patch)

func major*(v: Version): int {.raises: [].} = v.major
func minor*(v: Version): int {.raises: [].} = v.minor
func patch*(v: Version): int {.raises: [].} = v.patch

func parsePart(s: string): Result[int, VersionError] {.raises: [].} =
  if s.len == 0: return err(int, veShape)
  for c in s:
    if c notin {'0' .. '9'}: return err(int, veShape)
  if s.len > 1 and s[0] == '0': return err(int, veLeadingZero)
  if s.len > 6: return err(int, veTooLarge)
  var n = 0
  for c in s: n = n * 10 + (ord(c) - ord('0'))
  ok(n, VersionError)

func parseVersion*(text: string): Result[Version, VersionError] {.raises: [].} =
  ## `v1.2.3` → version(1, 2, 3). Only the form `$` prints is accepted, so parsing and printing
  ## are inverse.
  if text.len < 2 or text[0] != 'v': return err(Version, veShape)
  var parts: seq[string] = @[""]
  for c in text[1 .. ^1]:
    if c == '.': parts.add ""
    else: parts[^1].add c
  if parts.len != 3: return err(Version, veShape)
  var n: array[3, int]
  for i, p in parts:
    let r = parsePart(p)
    if r.isErr: return err(Version, r.error)
    n[i] = r.value
  ok(Version(major: n[0], minor: n[1], patch: n[2]), VersionError)

func `$`*(v: Version): string {.raises: [].} =
  "v" & $v.major & "." & $v.minor & "." & $v.patch

func `<`*(a, b: Version): bool {.raises: [].} =
  ## Major first, then minor, then patch.
  if a.major != b.major: a.major < b.major
  elif a.minor != b.minor: a.minor < b.minor
  else: a.patch < b.patch

func `<=`*(a, b: Version): bool {.raises: [].} = not (b < a)

func failures*[I, O](examples: openArray[Example[I, O]];
                     f: proc(x: I): O {.noSideEffect, raises: [].}): seq[string] {.raises: [].} =
  ## The names of the examples whose expected output `f` does not give, in table order.
  for e in examples:
    if f(e.input) != e.expected: result.add e.name
