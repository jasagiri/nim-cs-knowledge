## Builder as an immutable value with chained `func`s and a validating `build`.
##
## The OO pattern collects many optional settings step by step and creates the object only when it
## is complete. In Nim each `withX` returns a changed copy (the old builder stays valid), and
## `build` is the single place that checks the whole configuration and returns a `Result`.
## Use it when an object has many settings, some optional, with rules that span several fields.

import std/options
import nimcs/fp/result

type
  Port* = distinct int

  BuildError* = enum
    beEmptyHost, beBadPort, beTlsNeedsCert, beNoWorkers

  ServerConfig* = object
    host*: string
    port*: Port
    tls*: bool
    certPath*: Option[string]
    workers*: int

  ConfigBuilder* = object
    host: string
    port: int
    tls: bool
    certPath: Option[string]
    workers: int

func `==`*(a, b: Port): bool {.borrow.}

func initConfigBuilder*(): ConfigBuilder {.raises: [].} =
  ConfigBuilder(host: "", port: 8080, tls: false, certPath: none(string), workers: 1)

func withHost*(b: ConfigBuilder; host: string): ConfigBuilder {.raises: [].} =
  result = b
  result.host = host

func withPort*(b: ConfigBuilder; port: int): ConfigBuilder {.raises: [].} =
  result = b
  result.port = port

func withTls*(b: ConfigBuilder; certPath: string): ConfigBuilder {.raises: [].} =
  result = b
  result.tls = true
  result.certPath = if certPath.len > 0: some(certPath) else: none(string)

func withWorkers*(b: ConfigBuilder; workers: int): ConfigBuilder {.raises: [].} =
  result = b
  result.workers = workers

func build*(b: ConfigBuilder): Result[ServerConfig, BuildError] {.raises: [].} =
  ## Checks in a fixed order, so the reported error is deterministic.
  if b.host.len == 0:
    err(ServerConfig, beEmptyHost)
  elif b.port < 1 or b.port > 65535:
    err(ServerConfig, beBadPort)
  elif b.tls and b.certPath.isNone:
    err(ServerConfig, beTlsNeedsCert)
  elif b.workers < 1:
    err(ServerConfig, beNoWorkers)
  else:
    ok(ServerConfig(host: b.host, port: Port(b.port), tls: b.tls,
                    certPath: b.certPath, workers: b.workers), BuildError)
