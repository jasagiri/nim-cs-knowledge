## `Result[T, E]`: a value or the reason there is none (ADR-NCK-0002 S2).
##
## A small, dependency-free version of what `results` (Status) offers, so that every module and
## every dataset record compiles with the standard library alone. The names (`ok`, `err`, `isOk`,
## `map`, `flatMap`, `mapErr`, `valueOr`) resemble those of the `results` package, but the API is
## not compatible: here `ok` and `err` take a type argument (`ok(1, string)`, `err(int, "e")`),
## and reading `.value` of an error, or `.error` of a success, raises `FieldDefect` instead of
## following the `results` rules. Check `isOk` first, or leave the railway with `valueOr`.
## A program that already uses `results` should keep using it and not mix the two types.

type
  Result*[T, E] = object
    case isOk*: bool
    of true:
      value*: T
    of false:
      error*: E

func ok*[T, E](v: T; _: typedesc[E]): Result[T, E] {.raises: [].} =
  Result[T, E](isOk: true, value: v)

func err*[T, E](_: typedesc[T]; e: E): Result[T, E] {.raises: [].} =
  Result[T, E](isOk: false, error: e)

func isErr*[T, E](r: Result[T, E]): bool {.raises: [].} = not r.isOk

func map*[T, E, U](r: Result[T, E]; f: proc(x: T): U {.noSideEffect, raises: [].}): Result[U, E] {.raises: [].} =
  ## Functor law (spec FP-RESULT-01): r.map(identity) == r; r.map(f).map(g) == r.map(g ∘ f).
  if r.isOk: Result[U, E](isOk: true, value: f(r.value))
  else: Result[U, E](isOk: false, error: r.error)

func flatMap*[T, E, U](r: Result[T, E];
    f: proc(x: T): Result[U, E] {.noSideEffect, raises: [].}): Result[U, E] {.raises: [].} =
  ## The railway: the first error stops the chain (spec FP-RESULT-02).
  if r.isOk: f(r.value)
  else: Result[U, E](isOk: false, error: r.error)

func mapErr*[T, E, F](r: Result[T, E]; f: proc(e: E): F {.noSideEffect, raises: [].}): Result[T, F] {.raises: [].} =
  if r.isOk: Result[T, F](isOk: true, value: r.value)
  else: Result[T, F](isOk: false, error: f(r.error))

func valueOr*[T, E](r: Result[T, E]; fallback: T): T {.raises: [].} =
  if r.isOk: r.value else: fallback

func `==`*[T, E](a, b: Result[T, E]): bool {.raises: [].} =
  if a.isOk != b.isOk: false
  elif a.isOk: a.value == b.value
  else: a.error == b.error
