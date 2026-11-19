import std/unittest
import std/options
import propcheck
import nimcs/fp/result
import nimcs/patterns/builder

type Settings = (string, int, int)

func settings(): Gen[Settings] {.raises: [ValueError].} =
  pair(stringOf("abcd.", 1, 8), pair(intIn(1, 65535), intIn(1, 16))).map(
    proc(p: (string, (int, int))): Settings {.raises: [].} = (p[0], p[1][0], p[1][1]))

func apply(s: Settings): ConfigBuilder {.raises: [].} =
  initConfigBuilder().withHost(s[0]).withPort(s[1]).withWorkers(s[2])

func validBuilder(): ConfigBuilder {.raises: [].} =
  initConfigBuilder().withHost("h").withPort(80)

# SPEC: GOF-BUILDER-01
test "GOF-BUILDER-01 Given a builder, when a setter is applied, then the original still builds what it built before":
  let outcome = check(pair(settings(), intIn(-5, 70000)), proc(p: (Settings, int)): bool {.raises: [CatchableError].} =
    let base = apply(p[0])
    let before = base.build
    let changed = base.withPort(p[1]).withHost("other")
    discard changed.build
    base.build == before)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-BUILDER-02
test "GOF-BUILDER-02 Given each invalid setting, when built, then its own error is reported":
  check initConfigBuilder().build.error == beEmptyHost
  check validBuilder().withPort(0).build.error == beBadPort
  check validBuilder().withPort(65536).build.error == beBadPort
  check validBuilder().withTls("").build.error == beTlsNeedsCert
  check validBuilder().withWorkers(0).build.error == beNoWorkers

# SPEC: GOF-BUILDER-02
test "GOF-BUILDER-02 Given several invalid settings at once, when built, then the first check in order wins":
  let bad = initConfigBuilder().withPort(0).withTls("").withWorkers(0)
  check bad.build.error == beEmptyHost
  check bad.withHost("h").build.error == beBadPort
  check bad.withHost("h").withPort(1).build.error == beTlsNeedsCert
  check bad.withHost("h").withPort(1).withTls("c.pem").build.error == beNoWorkers

# SPEC: GOF-BUILDER-03
test "GOF-BUILDER-03 Given valid settings, when built, then the configuration holds them":
  let outcome = check(settings(), proc(s: Settings): bool {.raises: [CatchableError].} =
    let r = apply(s).build
    r.isOk and r.value.host == s[0] and r.value.port == Port(s[1]) and
      r.value.workers == s[2] and not r.value.tls and r.value.certPath.isNone)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-BUILDER-03
test "GOF-BUILDER-03 Given TLS with a certificate, when built, then the certificate is kept":
  let r = validBuilder().withTls("c.pem").build
  check r.isOk
  check r.value.tls
  check r.value.certPath == some("c.pem")

# SPEC: GOF-BUILDER-04
test "GOF-BUILDER-04 Given setters of different fields, when applied in either order, then the result is the same":
  let outcome = check(pair(settings(), intIn(-5, 70000)), proc(p: (Settings, int)): bool {.raises: [CatchableError].} =
    let b = apply(p[0])
    b.withHost("x").withPort(p[1]).build == b.withPort(p[1]).withHost("x").build)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-BUILDER-04
test "GOF-BUILDER-04 Given a setter, when applied twice, then it equals once":
  let outcome = check(pair(settings(), intIn(-5, 70000)), proc(p: (Settings, int)): bool {.raises: [CatchableError].} =
    let b = apply(p[0])
    b.withPort(p[1]).withPort(p[1]).build == b.withPort(p[1]).build)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-BUILDER-05
test "GOF-BUILDER-05 Given any other settings, when no host is set, then the build fails":
  let outcome = check(pair(intIn(-5, 70000), intIn(-2, 8)), proc(p: (int, int)): bool {.raises: [CatchableError].} =
    let r = initConfigBuilder().withPort(p[0]).withWorkers(p[1]).build
    r.isErr and r.error == beEmptyHost)
  checkpoint describe(outcome)
  check outcome.passed
