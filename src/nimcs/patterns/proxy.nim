## Proxy as a record of procs wrapping another record of procs.
##
## The OO pattern puts a stand-in with the same interface in front of an object to control access to
## it (protection), to delay its cost (virtual) or to remember its answers (caching). In Nim the
## interface is an object with a `fetch` proc field, and a fetch has three outcomes that a caller
## must be able to tell apart: a value, an absent key (`ok(none)`), and a refusal (`err`).
## A protection proxy (`guarded`) is a func `Source -> Source` and is fully substitutable. A cache
## needs state, so `Cached` is an explicit value and `lookup` returns the updated cache: this is a
## *different* interface and a `Cached` is not a `Source`. `asSource` gives a read-only view that is
## a `Source` (it answers from the cache when it can, else asks the real source, and remembers
## nothing). Use it when the caller must not know whether it talks to the real thing.

import std/[options, tables]
import nimcs/fp/result

type
  Refusal* = enum
    refDenied

  FetchResult* = Result[Option[string], Refusal]

  Fetch* = proc(key: string): FetchResult {.noSideEffect, raises: [].}
  Allow* = proc(key: string): bool {.noSideEffect, raises: [].}

  Source* = object
    fetch*: Fetch

  Cached* = object
    src: Source
    seen: Table[string, FetchResult]
    misses*: int

func guarded*(src: Source; allow: Allow): Source {.raises: [].} =
  ## Protection proxy: a denied key is answered with `err(refDenied)` and never reaches `src`.
  Source(fetch: proc(key: string): FetchResult {.noSideEffect, raises: [].} =
    if allow(key): src.fetch(key) else: err(Option[string], refDenied))

func initCached*(src: Source): Cached {.raises: [].} =
  Cached(src: src, seen: initTable[string, FetchResult](), misses: 0)

func lookup*(c: Cached; key: string): tuple[cache: Cached, value: FetchResult] {.raises: [].} =
  ## Caching proxy: the source is asked once per key. Every answer is remembered, an absent key
  ## and a refusal included, so a source whose answers change needs a fresh `Cached`.
  if c.seen.hasKey(key):
    (c, c.seen.getOrDefault(key, ok(none(string), Refusal)))
  else:
    var next = c
    let v = c.src.fetch(key)
    next.seen[key] = v
    next.misses += 1
    (next, v)

func asSource*(c: Cached): Source {.raises: [].} =
  ## Read-only view of the cache as a `Source`; its answers equal the real source's.
  Source(fetch: proc(key: string): FetchResult {.noSideEffect, raises: [].} =
    if c.seen.hasKey(key): c.seen.getOrDefault(key, ok(none(string), Refusal))
    else: c.src.fetch(key))
