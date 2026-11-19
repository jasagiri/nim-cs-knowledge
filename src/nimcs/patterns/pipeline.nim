## Pipeline: a middleware is a function from handler to handler, so a stack is function composition.
##
## A `Handler` turns a request into `Ok(response)` or `Err(error)`. A `Middleware` wraps a
## handler and returns a handler: it may refuse before calling the inner one (`requireUser`),
## change what comes back (`tagged`), or do nothing (`identity`). `andThen` composes two
## middlewares; it is associative with `identity` as unit, so any grouping of the same stack
## behaves the same and the stack is easy to test piece by piece. Handlers here are pure
## (`noSideEffect`); real logging or metrics would sit in the shell around the outermost handler.

import nimcs/fp/result

type
  Request* = object
    path*, user*, body*: string

  Response* = object
    status*: int
    body*: string

  HttpError* = object
    status*: int
    message*: string

  Handler* = proc(req: Request): Result[Response, HttpError] {.noSideEffect, raises: [].}

  Middleware* = proc(next: Handler): Handler {.noSideEffect, raises: [].}

func identity*(): Middleware {.raises: [].} =
  ## Passes the inner handler through untouched.
  proc(next: Handler): Handler {.noSideEffect, raises: [].} = next

func andThen*(outer, inner: Middleware): Middleware {.raises: [].} =
  ## `outer` sees the request first and the response last.
  proc(next: Handler): Handler {.noSideEffect, raises: [].} = outer(inner(next))

func compose*(ms: openArray[Middleware]): Middleware {.raises: [].} =
  ## The first element is outermost; the empty list is `identity`.
  result = identity()
  for i in countdown(ms.high, 0):
    result = ms[i].andThen(result)

func requireUser*(): Middleware {.raises: [].} =
  ## Refuses a request with no user, with status 401, without calling the inner handler.
  proc(next: Handler): Handler {.noSideEffect, raises: [].} =
    proc(req: Request): Result[Response, HttpError] {.noSideEffect, raises: [].} =
      if req.user.len == 0:
        err(Response, HttpError(status: 401, message: "login required"))
      else:
        next(req)

func limitBody*(maxLen: int): Middleware {.raises: [].} =
  ## Refuses a body longer than `maxLen` bytes with status 413.
  proc(next: Handler): Handler {.noSideEffect, raises: [].} =
    proc(req: Request): Result[Response, HttpError] {.noSideEffect, raises: [].} =
      if req.body.len > maxLen:
        err(Response, HttpError(status: 413, message: "body too large"))
      else:
        next(req)

func tagged*(tag: string): Middleware {.raises: [].} =
  ## Puts `tag & ">"` in front of a successful response body; errors pass through.
  proc(next: Handler): Handler {.noSideEffect, raises: [].} =
    proc(req: Request): Result[Response, HttpError] {.noSideEffect, raises: [].} =
      let reply = next(req)
      if reply.isOk:
        ok(Response(status: reply.value.status, body: tag & ">" & reply.value.body), HttpError)
      else:
        reply
