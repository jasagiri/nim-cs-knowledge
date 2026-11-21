## Replace conditional with polymorphism: a tag and an if-chain become a variant and a closed `case`.
##
## The "before" shape keeps every field of every kind in one record next to a tag, and each
## routine asks the tag with an `if` chain that ends in a quiet default. Here that is shipping
## cost for a parcel: `FlatParcel` and `costBefore`. The "after" shapes give each kind only its
## own data and make the compiler list the kinds a routine forgot. In this style the polymorphism
## is not inheritance or `method`; it is either an object variant with an exhaustive `case`
## (`Parcel`, `cost`), which is right when the set of kinds is closed and the operations grow, or
## a record of procs (`Tariff`), which is right when new kinds arrive from outside and the set of
## operations is small and fixed. Money is whole cents, so the shapes can be compared with `==`.

type
  Kind* = enum
    kStandard, kExpress, kPickup

  FlatParcel* = object
    ## Before: every field exists for every kind; `distanceKm` means nothing for a standard parcel.
    kind*: Kind
    weightG*: int
    distanceKm*: int

  Parcel* = object
    ## After (variant): a field exists only for the kind that owns it.
    case kind*: Kind
    of kStandard:
      weightG*: int
    of kExpress:
      expressWeightG*: int
      distanceKm*: int
    of kPickup:
      discard

  Tariff* = object
    ## After (record of procs): the operation travels with the value.
    price*: proc(): int {.noSideEffect, raises: [].}

const
  CentsPerHundred = 3     # cents per started 100 g, see `perHundred`
  ExpressBase = 500
  ExpressPerKm = 2

func perHundred(weightG: int): int {.raises: [].} =
  ## Started hundreds of grams; a negative weight counts as zero.
  if weightG <= 0: 0 else: (weightG + 99) div 100

func costBefore*(p: FlatParcel): int {.raises: [].} =
  ## Before: an `if` chain on the tag. A kind added to `Kind` falls into the last branch silently.
  if p.kind == kStandard:
    perHundred(p.weightG) * CentsPerHundred
  elif p.kind == kExpress:
    ExpressBase + perHundred(p.weightG) * CentsPerHundred * 2 + max(p.distanceKm, 0) * ExpressPerKm
  else:
    0

func cost*(p: Parcel): int {.raises: [].} =
  ## After: one branch per kind and no `else`, so a new `Kind` is a compile error here.
  case p.kind
  of kStandard:
    perHundred(p.weightG) * CentsPerHundred
  of kExpress:
    ExpressBase + perHundred(p.expressWeightG) * CentsPerHundred * 2 + max(p.distanceKm, 0) * ExpressPerKm
  of kPickup:
    0

func toParcel*(p: FlatParcel): Parcel {.raises: [].} =
  ## The migration step: the loose record becomes the variant that keeps only what its kind uses.
  case p.kind
  of kStandard: Parcel(kind: kStandard, weightG: p.weightG)
  of kExpress: Parcel(kind: kExpress, expressWeightG: p.weightG, distanceKm: p.distanceKm)
  of kPickup: Parcel(kind: kPickup)

func standard*(weightG: int): Tariff {.raises: [].} =
  Tariff(price: proc(): int {.noSideEffect, raises: [].} = perHundred(weightG) * CentsPerHundred)

func express*(weightG, distanceKm: int): Tariff {.raises: [].} =
  Tariff(price: proc(): int {.noSideEffect, raises: [].} =
    ExpressBase + perHundred(weightG) * CentsPerHundred * 2 + max(distanceKm, 0) * ExpressPerKm)

func pickup*(): Tariff {.raises: [].} =
  Tariff(price: proc(): int {.noSideEffect, raises: [].} = 0)

func toTariff*(p: FlatParcel): Tariff {.raises: [].} =
  ## The same migration into the record-of-procs shape.
  case p.kind
  of kStandard: standard(p.weightG)
  of kExpress: express(p.weightG, p.distanceKm)
  of kPickup: pickup()

func cost*(t: Tariff): int {.raises: [].} = t.price()

func total*(ps: openArray[Parcel]): int {.raises: [].} =
  ## Sum of costs; the caller never asks which kind a parcel is.
  for p in ps: result += p.cost
