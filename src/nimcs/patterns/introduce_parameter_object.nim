## Introduce parameter object: a group of arguments that travel together becomes one value.
##
## `selectLoose` takes six arguments, four of them integers in a row, so swapping `maxPrice` and
## `minRating` compiles and returns nonsense. The parameter object `Filter` names each field,
## carries defaults that mean "no limit", and gets its own small operations: `withPrice`,
## `withMinRating`, `inStockOnly`, `limited`. `select` takes the products and the filter. Because
## the filter is data, it can be stored, compared, combined (`narrowedBy`) and tested on its own,
## which six loose arguments cannot. Use it when the same group of three or more parameters is
## passed through more than one routine, or when callers must remember an argument order. For
## variants of behaviour, not of data, pass a record of procs instead (`dependency_record`).

type
  Product* = object
    id*: int
    price*: int        ## yen
    rating*: int       ## 0 .. 5
    inStock*: bool

  Filter* = object
    ## The default value of every field means "no restriction".
    minPrice*: int
    maxPrice*: int
    minRating*: int
    onlyInStock*: bool
    limit*: int        ## 0 means no limit

type
  StockRule* = enum
    srAny, srInStockOnly

const NoLimit* = 0

func noFilter*(): Filter {.raises: [].} =
  Filter(minPrice: 0, maxPrice: high(int), minRating: 0, onlyInStock: false, limit: NoLimit)

func selectLoose*(items: openArray[Product]; minPrice, maxPrice, minRating: int;
    stock: StockRule; limit: int): seq[Product] {.raises: [].} =
  ## Before: the order of the three integers is the whole contract.
  for p in items:
    if limit != NoLimit and result.len >= limit: break
    if p.price >= minPrice and p.price <= maxPrice and p.rating >= minRating and
        (stock == srAny or p.inStock):
      result.add p

func withPrice*(f: Filter; minPrice, maxPrice: int): Filter {.raises: [].} =
  Filter(minPrice: minPrice, maxPrice: maxPrice, minRating: f.minRating,
    onlyInStock: f.onlyInStock, limit: f.limit)

func withMinRating*(f: Filter; minRating: int): Filter {.raises: [].} =
  Filter(minPrice: f.minPrice, maxPrice: f.maxPrice, minRating: minRating,
    onlyInStock: f.onlyInStock, limit: f.limit)

func inStockOnly*(f: Filter): Filter {.raises: [].} =
  Filter(minPrice: f.minPrice, maxPrice: f.maxPrice, minRating: f.minRating,
    onlyInStock: true, limit: f.limit)

func limited*(f: Filter; limit: int): Filter {.raises: [].} =
  Filter(minPrice: f.minPrice, maxPrice: f.maxPrice, minRating: f.minRating,
    onlyInStock: f.onlyInStock, limit: limit)

func matches*(f: Filter; p: Product): bool {.raises: [].} =
  p.price >= f.minPrice and p.price <= f.maxPrice and p.rating >= f.minRating and
    (not f.onlyInStock or p.inStock)

func select*(items: openArray[Product]; f: Filter): seq[Product] {.raises: [].} =
  ## After: the same selection, in list order, up to `limit` matches.
  for p in items:
    if f.limit != NoLimit and result.len >= f.limit: break
    if f.matches(p):
      result.add p

func narrowedBy*(a, b: Filter): Filter {.raises: [].} =
  ## Both filters at once: the tighter bound of each field and the smaller non-zero limit.
  let lim =
    if a.limit == NoLimit: b.limit
    elif b.limit == NoLimit: a.limit
    else: min(a.limit, b.limit)
  Filter(minPrice: max(a.minPrice, b.minPrice), maxPrice: min(a.maxPrice, b.maxPrice),
    minRating: max(a.minRating, b.minRating), onlyInStock: a.onlyInStock or b.onlyInStock, limit: lim)
