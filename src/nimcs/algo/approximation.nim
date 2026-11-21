## Approximation algorithm: a vertex cover at most twice the optimum, from a maximal matching.
##
## A vertex cover is a set of vertices that touches every edge; finding a smallest one is NP-hard.
## The 2-approximation scans the edges in order and, whenever an edge has both ends still
## uncovered, takes that edge into a matching and puts both ends into the cover. The matched edges
## share no vertex, and any cover must contain at least one end of each of them, so the optimum is
## at least the matching size m while the answer has at most 2m vertices: a guaranteed ratio of 2,
## whatever the graph. The ratio is tight (a path on four vertices, scanned left to right, picks
## all four where two suffice). Use it when an exact cover is too expensive and a bounded error
## is acceptable; reach for an exact search only for small graphs.
##
## The graph must be undirected. Edges are scanned in `edges(g)` order (ascending source, target)
## so the answer is deterministic. A self-loop `v - v` is covered only by `v` itself, so it joins
## the matching with the single vertex `v`.

import nimcs/fp/result
import nimcs/algo/graph

type CoverResult* = object
  ## The matching that was built and the cover derived from it.
  matching*: seq[Edge]    ## pairwise vertex-disjoint edges, in scan order
  cover*: seq[int]        ## ascending vertices of the cover

func maximalMatchingCover*(g: Graph): Result[CoverResult, GraphError] {.raises: [].} =
  ## A maximal set of vertex-disjoint edges (no further edge can be added) and the vertices they
  ## touch. Fails with `geNotUndirected` for a directed graph (APPROX-VC-06). Every edge of the
  ## graph has an end in `cover` (APPROX-VC-01) and `cover.len <= 2 * matching.len`
  ## (APPROX-VC-02).
  if g.isDirected:
    return err(CoverResult, geNotUndirected)
  var covered = newSeq[bool](g.vertexCount)
  var matching: seq[Edge]
  for e in g.edges:
    if not covered[e.source] and not covered[e.target]:
      covered[e.source] = true
      covered[e.target] = true
      matching.add e
  var cover: seq[int]
  for v in 0 ..< g.vertexCount:
    if covered[v]: cover.add v
  ok(CoverResult(matching: matching, cover: cover), GraphError)

func vertexCover2Approx*(g: Graph): Result[seq[int], GraphError] {.raises: [].} =
  ## The cover of `maximalMatchingCover`, ascending: at most twice the size of a smallest cover
  ## (APPROX-VC-03).
  let r = maximalMatchingCover(g)
  if r.isErr:
    return err(seq[int], r.error)
  ok(r.value.cover, GraphError)

func isVertexCover*(g: Graph; cover: openArray[int]): bool {.raises: [].} =
  ## Does every edge of `g` have an end in `cover`? Vertices outside the graph never help.
  var chosen = newSeq[bool](g.vertexCount)
  for v in cover:
    if g.inRange(v):
      chosen[v] = true
  for e in g.edges:
    if not chosen[e.source] and not chosen[e.target]:
      return false
  true
