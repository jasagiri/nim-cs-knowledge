## Backtracking as a pure generator: a search tree is described by two functions, `children`
## (the ways to extend a partial state) and `isSolution`, and `backtrack` returns every solution in
## depth-first, left-to-right order. Nothing is mutated by the caller; the only `var` is the list being
## collected inside the walk.
##
## Use it for constraint problems with a small search tree: permutations, combinations, n-queens,
## sudoku-like puzzles. Pruning lives in `children`: return only extensions that can still
## lead to a solution. When the number of solutions is huge or only one is needed, use
## `firstSolution`; when sub-problems repeat, switch to dynamic programming (`memoization`).
##
## The domain helpers refuse sizes whose answer would not be a sensible list (negative, or large
## enough to take minutes); the limits are exported constants.

import std/options

type
  Children*[S] = proc(s: S): seq[S] {.noSideEffect, raises: [].}
  Accept*[S] = proc(s: S): bool {.noSideEffect, raises: [].}

const
  maxPermutationSize*: int = 9
  maxCombinationSize*: int = 20
  maxQueensSize*: int = 10

func walk[S](s: S; children: Children[S]; accept: Accept[S]; found: var seq[S]) {.raises: [].} =
  if accept(s):
    found.add s
  for c in children(s):
    walk(c, children, accept, found)

func backtrack*[S](start: S; children: Children[S]; accept: Accept[S]): seq[S] {.raises: [].} =
  ## Every state reachable from `start` for which `accept` holds, in pre-order (TECH-BT-GEN-01,
  ## TECH-BT-GEN-02). The same arguments always give the same list.
  result = @[]
  walk(start, children, accept, result)

func firstWalk[S](s: S; children: Children[S]; accept: Accept[S]): Option[S] {.raises: [].} =
  if accept(s):
    return some(s)
  for c in children(s):
    let r = firstWalk(c, children, accept)
    if r.isSome:
      return r
  none(S)

func firstSolution*[S](start: S; children: Children[S]; accept: Accept[S]): Option[S] {.raises: [].} =
  ## The first element `backtrack` would return, without visiting the rest of the tree (TECH-BT-GEN-03).
  firstWalk(start, children, accept)

func permutations*(n: int): Option[seq[seq[int]]] {.raises: [].} =
  ## All orderings of 0 ..< n in lexicographic order; one empty ordering when n is 0. None when
  ## n < 0 or n > `maxPermutationSize` (TECH-BT-PERM-01 .. TECH-BT-PERM-03).
  if n < 0 or n > maxPermutationSize:
    return none(seq[seq[int]])
  func kids(s: seq[int]): seq[seq[int]] {.raises: [].} =
    result = @[]
    if s.len < n:
      for v in 0 ..< n:
        if v notin s:
          result.add s & @[v]
  func done(s: seq[int]): bool {.raises: [].} = s.len == n
  some(backtrack(newSeq[int](), kids, done))

func combinations*(n, k: int): Option[seq[seq[int]]] {.raises: [].} =
  ## All k-element subsets of 0 ..< n, each ascending, in lexicographic order. Empty when k > n.
  ## None when n or k is negative or n > `maxCombinationSize` (TECH-BT-COMB-01, TECH-BT-COMB-02).
  if n < 0 or k < 0 or n > maxCombinationSize:
    return none(seq[seq[int]])
  func kids(s: seq[int]): seq[seq[int]] {.raises: [].} =
    result = @[]
    if s.len < k:
      let first = if s.len == 0: 0 else: s[s.len - 1] + 1
      for v in first ..< n:
        if n - v >= k - s.len:      # enough values left to reach size k
          result.add s & @[v]
  func done(s: seq[int]): bool {.raises: [].} = s.len == k
  some(backtrack(newSeq[int](), kids, done))

func safeToPlace(cols: seq[int]; col: int): bool {.raises: [].} =
  let row = cols.len
  for r in 0 ..< row:
    if cols[r] == col or abs(cols[r] - col) == row - r:
      return false
  true

func nQueens*(n: int): Option[seq[seq[int]]] {.raises: [].} =
  ## All placements of n non-attacking queens on an n x n board, as the column of the queen in each
  ## row, in lexicographic order. n = 0 has one (empty) placement. None when n < 0 or n >
  ## `maxQueensSize` (TECH-BT-QUEENS-01, TECH-BT-QUEENS-02).
  if n < 0 or n > maxQueensSize:
    return none(seq[seq[int]])
  func kids(s: seq[int]): seq[seq[int]] {.raises: [].} =
    result = @[]
    if s.len < n:
      for c in 0 ..< n:
        if safeToPlace(s, c):
          result.add s & @[c]
  func done(s: seq[int]): bool {.raises: [].} = s.len == n
  some(backtrack(newSeq[int](), kids, done))
