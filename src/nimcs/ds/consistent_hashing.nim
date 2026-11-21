## Consistent hashing: a hash ring with virtual nodes, as a value.
##
## Keys and nodes are hashed onto a circle of 2^64 positions. A node owns several positions (its
## virtual nodes, `vnodes` of them, named `<node>#0`, `<node>#1`, ...), and a key belongs to the node
## at the first position at or after the key's own, wrapping around at the top. Adding a node takes
## over only the arcs just before its new positions and removing a node gives only its arcs to the
## next positions, so a change in membership moves a small share of the keys instead of nearly all of
## them, as `hash mod n` would. Many virtual nodes per node smooth the share each node gets.
##
## The hash, `ringHash`, is fixed in this module (FNV-1a 64 followed by a bit mixer), so owners are the
## same on every run, platform and compiler version, and a ring's layout depends only on which nodes
## are present, not on the order they were added. It is not a cryptographic hash.

import std/[algorithm, options]
import nimcs/fp/result
export result

type
  RingError* = enum
    reNoVnodes,             ## `vnodes` below 1
    reEmptyName             ## a node with an empty name
  Point = object
    pos: uint64
    node: string
  Ring* = object
    vnodes: int
    members: seq[string]    ## sorted, no duplicates
    points: seq[Point]      ## sorted by (pos, node)

func ringHash*(s: string): uint64 {.raises: [].} =
  ## FNV-1a 64 over the bytes, then the 64-bit finalizer of MurmurHash3 so that nearby strings
  ## land far apart on the ring. Fixed forever: stored placements depend on it.
  var h = 0xcbf29ce484222325'u64
  for c in s:
    h = (h xor uint64(ord(c))) * 0x100000001b3'u64
  h = h xor (h shr 33)
  h = h * 0xff51afd7ed558ccd'u64
  h = h xor (h shr 33)
  h = h * 0xc4ceb9fe1a85ec53'u64
  h xor (h shr 33)

func newRing*(vnodes: int): Result[Ring, RingError] {.raises: [].} =
  ## An empty ring whose nodes will each take `vnodes` positions (at least 1; 64 to 256 is typical).
  if vnodes < 1: err(Ring, reNoVnodes)
  else: ok(Ring(vnodes: vnodes), RingError)

func vnodeCount*(r: Ring): int {.raises: [].} =
  r.vnodes

func len*(r: Ring): int {.raises: [].} =
  ## Number of nodes.
  r.members.len

func nodes*(r: Ring): seq[string] {.raises: [].} =
  ## The nodes in name order.
  r.members

func contains*(r: Ring; node: string): bool {.raises: [].} =
  binarySearch(r.members, node) >= 0

func `==`*(a, b: Ring): bool {.raises: [].} =
  ## Same vnode count and same positions (which implies the same nodes).
  if a.vnodes != b.vnodes or a.points.len != b.points.len: return false
  for i in 0 ..< a.points.len:
    if a.points[i].pos != b.points[i].pos or a.points[i].node != b.points[i].node: return false
  true

func cmpPoint(a, b: Point): int =
  if a.pos != b.pos: (if a.pos < b.pos: -1 else: 1)
  else: cmp(a.node, b.node)

func vnodePosition*(node: string; i: int): uint64 {.raises: [].} =
  ## Where virtual node `i` of `node` sits on the ring. The name `node#i` is unambiguous: the digits
  ## after the last `#` are the index.
  ringHash(node & "#" & $i)

func addNode*(r: Ring; node: string): Result[Ring, RingError] {.raises: [].} =
  ## The ring with `node` added; the same ring when it is already there.
  if node.len == 0: return err(Ring, reEmptyName)
  if node in r: return ok(r, RingError)
  var points = r.points
  for i in 0 ..< r.vnodes:
    points.add Point(pos: vnodePosition(node, i), node: node)
  points.sort(cmpPoint)
  var members = r.members
  members.add node
  members.sort()
  ok(Ring(vnodes: r.vnodes, members: members, points: points), RingError)

func removeNode*(r: Ring; node: string): Ring {.raises: [].} =
  ## The ring without `node`; the same ring when it is not there.
  if node notin r: return r
  var points: seq[Point]
  for p in r.points:
    if p.node != node: points.add p
  var members: seq[string]
  for m in r.members:
    if m != node: members.add m
  Ring(vnodes: r.vnodes, members: members, points: points)

func firstAtOrAfter(r: Ring; h: uint64): int =
  ## Index of the first point with position >= h; wraps to 0 past the end. The ring must not be empty.
  var lo = 0
  var hi = r.points.len
  while lo < hi:
    let mid = lo + (hi - lo) div 2
    if r.points[mid].pos < h: lo = mid + 1
    else: hi = mid
  if lo == r.points.len: 0 else: lo

func owner*(r: Ring; key: string): Option[string] {.raises: [].} =
  ## The node that owns `key`; none when the ring has no node. O(log(nodes * vnodes)).
  if r.points.len == 0: none(string)
  else: some(r.points[firstAtOrAfter(r, ringHash(key))].node)

func owners*(r: Ring; key: string; count: int): seq[string] {.raises: [].} =
  ## Up to `count` distinct nodes for `key` (a replica list): the owner first, then the nodes met
  ## walking clockwise. Fewer when the ring has fewer nodes.
  if r.points.len == 0 or count < 1: return @[]
  let start = firstAtOrAfter(r, ringHash(key))
  var step = 0
  while step < r.points.len and result.len < count:
    let node = r.points[(start + step) mod r.points.len].node
    if node notin result: result.add node
    inc step
