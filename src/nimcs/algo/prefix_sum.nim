## Prefix sums, difference arrays and two-dimensional prefix sums.
##
## Use a prefix-sum table when many range-sum questions are asked of data that does not change:
## one O(n) pass pays for O(1) per question (sum of xs[l ..< r] is prefix[r] - prefix[l]). Use a
## difference array for the opposite job, many "add d to every element of l ..< r" updates followed
## by one read: store only the changes between neighbours, then a running sum restores the values.
## The two are inverses of each other. The 2-D table answers rectangle sums in O(1) by
## inclusion-exclusion. All ranges are half-open (`l ..< r`). Sums are `int`; the caller keeps them
## from overflowing. Nothing is changed in place, and an update returns a new value.

import nimcs/fp/result

type
  SpanError* = enum
    reOutOfBounds   ## an index outside 0 .. length (rows or columns for a rectangle)
    reReversed      ## the start of a range is after its end
    reRagged        ## the rows of a grid do not all have the same length

  PrefixSums* = object
    ## `sums[i]` is the sum of the first i elements, so `sums.len` is the element count plus one.
    sums: seq[int]

  PrefixSums2D* = object
    ## `sums[i * (cols + 1) + j]` is the sum of the rectangle of the first i rows and first j columns.
    rows, cols: int
    sums: seq[int]

func prefixOf*(xs: openArray[int]): PrefixSums {.raises: [].} =
  ## The table of running sums: entry 0 is 0 and entry i + 1 is entry i plus `xs[i]`
  ## (TECH-PREFIX-01).
  var sums = newSeq[int](xs.len + 1)
  for i, x in xs:
    sums[i + 1] = sums[i] + x
  PrefixSums(sums: sums)

func count*(p: PrefixSums): int {.raises: [].} =
  ## How many elements the table covers.
  p.sums.len - 1

func rangeSum*(p: PrefixSums; l, r: int): Result[int, SpanError] {.raises: [].} =
  ## The sum of the elements l ..< r, in O(1) (TECH-PREFIX-02). Fails with `reOutOfBounds` unless
  ## 0 <= l and r <= count, and with `reReversed` when l > r (TECH-PREFIX-03). `l == r` is the
  ## empty range, whose sum is 0.
  if l < 0 or r > p.count:
    return err(int, reOutOfBounds)
  if l > r:
    return err(int, reReversed)
  ok(p.sums[r] - p.sums[l], SpanError)

func differences*(xs: openArray[int]): seq[int] {.raises: [].} =
  ## The first element, then each element minus the one before: the changes between neighbours
  ## (TECH-PREFIX-04). The inverse of `fromDifferences`.
  for i, x in xs:
    result.add (if i == 0: x else: x - xs[i - 1])

func fromDifferences*(diffs: openArray[int]): seq[int] {.raises: [].} =
  ## The running sum of the changes: the values they describe (TECH-PREFIX-04).
  var running = 0
  for d in diffs:
    running += d
    result.add running

func applyRangeAdds*(n: int; adds: openArray[(int, int, int)]): Result[seq[int], SpanError] {.raises: [].} =
  ## Start from n zeros and add `delta` to every element of l ..< r for each (l, r, delta); the
  ## result is built from a difference array, so k updates cost O(n + k) and not O(n * k)
  ## (TECH-PREFIX-05). An update with a bad range fails the whole call with `reOutOfBounds`
  ## (outside 0 .. n; a negative `n` counts as outside) or `reReversed` (TECH-PREFIX-06).
  if n < 0:
    return err(seq[int], reOutOfBounds)
  var marks = newSeq[int](n + 1)         # one spare cell for a range that ends at n
  for (l, r, delta) in adds:
    if l < 0 or r > n:
      return err(seq[int], reOutOfBounds)
    if l > r:
      return err(seq[int], reReversed)
    marks[l] += delta
    marks[r] -= delta
  ok(fromDifferences(marks[0 ..< n]), SpanError)

func prefixOf2D*(grid: openArray[seq[int]]): Result[PrefixSums2D, SpanError] {.raises: [].} =
  ## The table of rectangle sums of a grid given as rows. Fails with `reRagged` when the rows differ
  ## in length (TECH-PREFIX-09). An empty grid, or a grid of empty rows, is fine.
  let cols = if grid.len == 0: 0 else: grid[0].len
  for row in grid:
    if row.len != cols:
      return err(PrefixSums2D, reRagged)
  let stride = cols + 1
  var sums = newSeq[int]((grid.len + 1) * stride)
  for i in 0 ..< grid.len:
    for j in 0 ..< cols:
      sums[(i + 1) * stride + j + 1] = grid[i][j] + sums[i * stride + j + 1] + sums[(i + 1) * stride + j] -
        sums[i * stride + j]
  ok(PrefixSums2D(rows: grid.len, cols: cols, sums: sums), SpanError)

func rowCount*(p: PrefixSums2D): int {.raises: [].} = p.rows

func columnCount*(p: PrefixSums2D): int {.raises: [].} = p.cols

func rectSum*(p: PrefixSums2D; row0, col0, row1, col1: int): Result[int, SpanError] {.raises: [].} =
  ## The sum of the cells in rows row0 ..< row1 and columns col0 ..< col1, from four table
  ## entries: whole block minus the two strips plus the corner counted twice (TECH-PREFIX-07).
  ## Fails like `rangeSum`, on either axis (TECH-PREFIX-08).
  if row0 < 0 or col0 < 0 or row1 > p.rows or col1 > p.cols:
    return err(int, reOutOfBounds)
  if row0 > row1 or col0 > col1:
    return err(int, reReversed)
  let stride = p.cols + 1
  ok(p.sums[row1 * stride + col1] - p.sums[row0 * stride + col1] - p.sums[row1 * stride + col0] +
    p.sums[row0 * stride + col0], SpanError)
