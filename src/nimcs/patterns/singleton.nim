## Singleton: avoid it. Pass the dependency as a value, or use an immutable module-level constant.
##
## The OO pattern guarantees one global instance with a global access point. Both halves cause
## trouble: hidden global state makes callers impure and hard to test. In Nim the two honest
## replacements are (1) a `const` or `let` of an immutable value when the thing really is fixed
## data (`DefaultSettings`), and (2) a record of procs given to the routines that need it (`Clock`),
## so a test passes a fixed clock and production passes the real one. Use this module as the
## "after" picture; it contains no mutable global.

type
  Settings* = object
    retries*: int
    label*: string

  Clock* = object
    now*: proc(): int64 {.noSideEffect, raises: [].}

const DefaultSettings* = Settings(retries: 3, label: "default")

func withRetries*(s: Settings; retries: int): Settings {.raises: [].} =
  ## A changed copy; `DefaultSettings` itself can never be modified.
  result = s
  result.retries = retries

func fixedClock*(t: int64): Clock {.raises: [].} =
  Clock(now: proc(): int64 {.noSideEffect, raises: [].} = t)

func stamp*(c: Clock; msg: string): string {.raises: [].} =
  ## Depends on its clock argument and on nothing else.
  $c.now() & ": " & msg
