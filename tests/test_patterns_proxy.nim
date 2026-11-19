import std/unittest
import std/options
import propcheck
import nimcs/fp/result
import nimcs/patterns/proxy

# A source whose answer encodes the key; "missing" is absent (ok(none)), not refused.
func echoFetch(key: string): FetchResult {.raises: [].} =
  if key == "missing": ok(none(string), Refusal) else: ok(some("value:" & key), Refusal)

let plain = Source(fetch: echoFetch)

# The proxy under test must be unable to reach this source for denied keys: it answers with a
# marker that must never be observed.
func leakyFetch(key: string): FetchResult {.raises: [].} =
  ok(some("LEAK:" & key), Refusal)

let leaky = Source(fetch: leakyFetch)

func keys(): Gen[string] {.raises: [ValueError].} =
  pick(["a", "b", "c", "missing", "secret", "secret2"])

let allowAll: Allow = proc(key: string): bool {.noSideEffect, raises: [].} = true
let noSecrets: Allow = proc(key: string): bool {.noSideEffect, raises: [].} =
  key.len < 6 or key[0 ..< 6] != "secret"

# SPEC: GOF-PROXY-01
test "GOF-PROXY-01 Given a proxy that allows every key, when fetching any key, then it answers as the source":
  let outcome = check(keys(), proc(k: string): bool {.raises: [CatchableError].} =
    guarded(plain, allowAll).fetch(k) == plain.fetch(k))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-PROXY-02
test "GOF-PROXY-02 Given a denied key, when fetching, then a refusal and the source is not asked":
  let outcome = check(keys(), proc(k: string): bool {.raises: [CatchableError].} =
    let r = guarded(leaky, noSecrets).fetch(k)
    if noSecrets(k): r == ok(some("LEAK:" & k), Refusal)
    else: r.isErr and r.error == refDenied)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-PROXY-02
test "GOF-PROXY-02 Given a refused key and an absent key, when fetched through the proxy, then the answers differ":
  let g = guarded(plain, noSecrets)
  check g.fetch("secret").isErr
  check g.fetch("missing").isOk
  check g.fetch("missing").value.isNone
  check g.fetch("secret") != g.fetch("missing")

# SPEC: GOF-PROXY-03
test "GOF-PROXY-03 Given any key, when looked up through the cache, then the value is the source's and a repeat changes nothing":
  let outcome = check(keys(), proc(k: string): bool {.raises: [CatchableError].} =
    let (c1, v1) = initCached(plain).lookup(k)
    let (c2, v2) = c1.lookup(k)
    v1 == plain.fetch(k) and v2 == v1 and c2.misses == c1.misses)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-PROXY-03
test "GOF-PROXY-03 Given a source that refuses, when looked up through the cache, then the refusal is returned as such":
  let refusing = guarded(plain, noSecrets)
  let (c, v) = initCached(refusing).lookup("secret")
  check v.isErr and v.error == refDenied
  check c.lookup("secret").value == v

# SPEC: GOF-PROXY-04
test "GOF-PROXY-04 Given any sequence of lookups, when done, then misses equals the number of distinct keys":
  let outcome = check(seqOf(keys(), 0, 15), proc(ks: seq[string]): bool {.raises: [CatchableError].} =
    var cache = initCached(plain)
    var uniq: seq[string] = @[]
    for k in ks:
      cache = cache.lookup(k).cache
      if k notin uniq: uniq.add(k)
    cache.misses == uniq.len)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-PROXY-05
test "GOF-PROXY-05 Given a cache, when viewed as a source, then it answers every key as the real source does":
  let outcome = check(pair(seqOf(keys(), 0, 6), keys()), proc(p: (seq[string], string)): bool {.raises: [CatchableError].} =
    let guardedSrc = guarded(plain, noSecrets)
    var cache = initCached(guardedSrc)
    for k in p[0]:
      cache = cache.lookup(k).cache
    cache.asSource.fetch(p[1]) == guardedSrc.fetch(p[1]))
  checkpoint describe(outcome)
  check outcome.passed
