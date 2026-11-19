import std/[unittest, options]
import propcheck
import nimcs/patterns/memento

type Settings = object
  volume: int
  muted: bool
  name: string

func `==`(a, b: Settings): bool {.raises: [].} =
  a.volume == b.volume and a.muted == b.muted and a.name == b.name

func recordAll(t: Timeline[int]; xs: seq[int]): Timeline[int] {.raises: [].} =
  result = t
  for x in xs: result = result.record(x)

# SPEC: GOF-MEMENTO-01
test "GOF-MEMENTO-01 Given a saved value, when the original is changed, then the saved value is unaffected":
  var live = Settings(volume: 3, muted: false, name: "den")
  let saved = live
  live.volume = 9
  live.name = "kitchen"
  check saved == Settings(volume: 3, muted: false, name: "den")
  check live != saved
  let changed = Settings(volume: 11, muted: saved.muted, name: saved.name)
  check saved.volume == 3
  check changed.volume == 11

# SPEC: GOF-MEMENTO-02
test "GOF-MEMENTO-02 Given any recorded value, when undone, then the previous present returns":
  let outcome = check(pair(intIn(-9, 9), seqOf(intIn(-9, 9), 1, 8)), proc(p: (int, seq[int])): bool {.raises: [CatchableError].} =
    let t = initTimeline(p[0], 100).recordAll(p[1])
    let before = t.record(1234)
    let u = before.undo
    u.isSome and u.get.current == t.current and u.get.history == t.history and u.get.futureLen == 1)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-MEMENTO-03
test "GOF-MEMENTO-03 Given an undone timeline, when redone, then the timeline equals the one before the undo":
  let outcome = check(seqOf(intIn(-9, 9), 1, 8), proc(xs: seq[int]): bool {.raises: [CatchableError].} =
    let t = initTimeline(0, 100).recordAll(xs)
    let r = t.undo.get.redo
    r.isSome and r.get == t)
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-MEMENTO-04
test "GOF-MEMENTO-04 Given any capacity, when many values are recorded, then the past never exceeds it and the newest are kept":
  let outcome = check(pair(intIn(-3, 6), seqOf(intIn(0, 99), 0, 20)), proc(p: (int, seq[int])): bool {.raises: [CatchableError].} =
    let cap = max(1, p[0])
    let t = initTimeline(-1, p[0]).recordAll(p[1])
    let all = @[-1] & p[1]            # every value ever present, oldest first
    let expectedPast = all[max(0, all.len - 1 - cap) ..< all.len - 1]
    t.pastLen <= cap and t.history == expectedPast & all[^1])
  checkpoint describe(outcome)
  check outcome.passed

# SPEC: GOF-MEMENTO-05
test "GOF-MEMENTO-05 Given a timeline with redo available, when a value is recorded, then redo is cleared":
  let t = initTimeline(0, 10).record(1).record(2).undo.get
  check t.futureLen == 1
  check t.record(7).futureLen == 0
  check t.record(7).redo.isNone

# SPEC: GOF-MEMENTO-06
test "GOF-MEMENTO-06 Given a fresh timeline, when undo or redo is asked, then it is none":
  let t = initTimeline("a", 5)
  check t.undo.isNone
  check t.redo.isNone
  check t.current == "a"

# SPEC: GOF-MEMENTO-07
test "GOF-MEMENTO-07 Given a timeline, when it is undone and the original kept, then the original value is untouched (persistence)":
  let t = initTimeline(0, 10).record(1).record(2)
  let u = t.undo.get
  check t.current == 2
  check t.history == @[0, 1, 2]
  check u.current == 1

type
  Box = ref object
    n: int

  Holder = object
    box: Box
    label: string

# SPEC: GOF-MEMENTO-08
test "GOF-MEMENTO-08 Given an object with a ref field, when copied and the original's referent changes, then the copy sees the change unless a fresh referent was built":
  let live = Holder(box: Box(n: 1), label: "a")
  let aliased = live                                   # copies the pointer, not the Box
  let rebuilt = Holder(box: Box(n: live.box.n), label: live.label)   # a real snapshot
  live.box.n = 9
  check aliased.box.n == 9
  check rebuilt.box.n == 1
