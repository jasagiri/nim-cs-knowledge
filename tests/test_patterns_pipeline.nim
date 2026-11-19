import std/unittest
import propcheck
import nimcs/fp/result
import nimcs/patterns/pipeline

type Reply = Result[Response, HttpError]

func echoHandler(req: Request): Reply {.raises: [].} =
  ok(Response(status: 200, body: req.path & ":" & req.body), HttpError)

func brokenHandler(req: Request): Reply {.raises: [].} =
  err(Response, HttpError(status: 500, message: "inner failed"))

func middlewareOf(k: int): Middleware {.raises: [].} =
  case k
  of 0: tagged("a")
  of 1: tagged("b")
  of 2: requireUser()
  of 3: limitBody(5)
  else: identity()

func stack(ks: seq[int]): Middleware {.raises: [].} =
  var ms: seq[Middleware]
  for k in ks: ms.add middlewareOf(k)
  compose(ms)

func requestOf(p: (string, (string, string))): Request {.raises: [].} =
  Request(path: p[0], user: p[1][0], body: p[1][1])

func requests(): Gen[Request] {.raises: [ValueError].} =
  pair(stringOf("ab", 0, 3), pair(stringOf("u", 0, 1), stringOf("xyz", 0, 10))).map(requestOf)

func kinds(): Gen[seq[int]] {.raises: [ValueError].} = seqOf(intIn(0, 4), 0, 5)

func run(m: Middleware; req: Request): Reply {.raises: [].} =
  m(Handler(echoHandler))(req)

# SPEC: PAT-PIPELINE-01
test "PAT-PIPELINE-01 Given any request, when the identity middleware wraps a handler, then the handler's answer is unchanged":
  let outcome = check(requests(), proc(req: Request): bool {.raises: [CatchableError].} =
    run(identity(), req) == echoHandler(req))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-PIPELINE-02
test "PAT-PIPELINE-02 Given three stacks, when composed with andThen in either grouping, then every request gets the same answer":
  let outcome = check(pair(requests(), pair(kinds(), pair(kinds(), kinds()))),
    proc(p: (Request, (seq[int], (seq[int], seq[int])))): bool {.raises: [CatchableError].} =
      let a = stack(p[1][0])
      let b = stack(p[1][1][0])
      let c = stack(p[1][1][1])
      run(a.andThen(b.andThen(c)), p[0]) == run(a.andThen(b).andThen(c), p[0]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-PIPELINE-03
test "PAT-PIPELINE-03 Given any stack, when identity is composed on either side, then the behaviour is unchanged":
  let outcome = check(pair(requests(), kinds()), proc(p: (Request, seq[int])): bool {.raises: [CatchableError].} =
    let m = stack(p[1])
    run(identity().andThen(m), p[0]) == run(m, p[0]) and run(m.andThen(identity()), p[0]) == run(m, p[0]))
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-PIPELINE-04
test "PAT-PIPELINE-04 Given a request without a user, when it passes requireUser, then it is refused with 401 whatever lies behind":
  let outcome = check(pair(requests(), kinds()), proc(p: (Request, seq[int])): bool {.raises: [CatchableError].} =
    let req = Request(path: p[0].path, user: "", body: p[0].body)
    let guarded = requireUser().andThen(stack(p[1]))
    let viaEcho = guarded(Handler(echoHandler))(req)
    let viaBroken = guarded(Handler(brokenHandler))(req)
    viaEcho == viaBroken and viaEcho.isErr and viaEcho.error.status == 401)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-PIPELINE-04
test "PAT-PIPELINE-04 Given an oversized body, when it passes limitBody, then it is refused with 413; at the limit it passes":
  let big = Request(path: "p", user: "u", body: "xxxxxx")
  let fits = Request(path: "p", user: "u", body: "xxxxx")
  check run(limitBody(5), big).error.status == 413
  check run(limitBody(5), fits).isOk

# SPEC: PAT-PIPELINE-05
test "PAT-PIPELINE-05 Given any list of tags, when composed, then the response body shows them outermost first before the handler's body":
  let outcome = check(pair(requests(), seqOf(intIn(0, 1), 0, 6)), proc(p: (Request, seq[int])): bool {.raises: [CatchableError].} =
    var expected = ""
    for k in p[1]: expected.add(if k == 0: "a>" else: "b>")
    let r = run(stack(p[1]), p[0])
    r.isOk and r.value.body == expected & p[0].path & ":" & p[0].body)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: PAT-PIPELINE-06
test "PAT-PIPELINE-06 Given two lists, when composed as one list or as two stacks, then the behaviour is the same; the empty list is identity":
  let outcome = check(pair(requests(), pair(kinds(), kinds())), proc(p: (Request, (seq[int], seq[int]))): bool {.raises: [CatchableError].} =
    run(stack(p[1][0] & p[1][1]), p[0]) == run(stack(p[1][0]).andThen(stack(p[1][1])), p[0]) and
      run(stack(@[]), p[0]) == echoHandler(p[0]))
  checkpoint describe(outcome)
  check outcome.passed
