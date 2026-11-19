## Function composition and pipelines (ADR-NCK-0002 S1, S3).
##
## `compose(f, g)` is "g, then f" as in mathematics; `andThen(f, g)` is the same function written in
## reading order ("f, then g"). `identity` is the neutral element, and composition is associative, so
## a pipeline can be grouped any way without changing its meaning. Use `composeAll` for a list of
## steps that all map a type to itself; use plain method-call chains (`x.parse.validate.render`)
## when the steps are known at the call site.

type
  Fn*[A, B] = proc(a: A): B {.noSideEffect, raises: [].}
    ## A pure function value: no side effects, no exceptions.

func identity*[T](x: T): T {.raises: [].} =
  ## The neutral element of composition.
  x

func compose*[A, B, C](f: proc(b: B): C {.noSideEffect, raises: [].};
    g: proc(a: A): B {.noSideEffect, raises: [].}): Fn[A, C] {.raises: [].} =
  ## `compose(f, g)(x) == f(g(x))`.
  result = proc(a: A): C {.noSideEffect, raises: [].} = f(g(a))

func andThen*[A, B, C](f: proc(a: A): B {.noSideEffect, raises: [].};
    g: proc(b: B): C {.noSideEffect, raises: [].}): Fn[A, C] {.raises: [].} =
  ## `f.andThen(g)(x) == g(f(x))`: the steps in the order they run.
  result = proc(a: A): C {.noSideEffect, raises: [].} = g(f(a))

func composeAll*[T](steps: openArray[Fn[T, T]]): Fn[T, T] {.raises: [].} =
  ## Runs the steps first to last. An empty list is `identity`.
  let copied = @steps
  result = proc(a: T): T {.noSideEffect, raises: [].} =
    var acc = a
    for step in copied:
      acc = step(acc)
    acc
