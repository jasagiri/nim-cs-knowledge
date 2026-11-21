## Decompose conditional: give each part of a long condition a name, and each branch a result type.
##
## A condition that mixes ages, weekdays and hours in one expression is read by running it in your
## head. Decomposing it means a small `func` per idea in the condition (`isChild`, `isWeekdaySenior`,
## `isDaytimeStudent`, `isEvening`), and a decision that is a short `case` or `if` over those names.
## Here the price of a museum ticket in yen. `priceBefore` is the single tangled expression;
## `tierOf` names the rule that applied and `priceOf` turns a tier into money, so the answer to
## "why did this visitor pay that?" is a value (`Tier`) and not a trace. Use it when a condition
## has more than two clauses or when you cannot say the rule aloud. It changes no result: the test
## compares both shapes on generated visitors.

type
  Visitor* = object
    age*: int          ## whole years
    isStudent*: bool
    weekday*: int      ## 0 = Monday .. 6 = Sunday
    hour*: int         ## 0 .. 23

  Tier* = enum
    tFree, tReduced, tFull

const
  FullPrice* = 1500
  ReducedPrice* = 800

func priceBefore*(v: Visitor): int {.raises: [].} =
  ## Before: every rule inline, precedence hidden in the parentheses.
  if v.age < 6 or (v.age >= 65 and v.weekday < 5):
    0
  elif (v.isStudent and v.age < 26 and v.hour < 17) or v.hour >= 20 or (v.age >= 65):
    ReducedPrice
  else:
    FullPrice

func isChild*(v: Visitor): bool {.raises: [].} = v.age < 6

func isSenior*(v: Visitor): bool {.raises: [].} = v.age >= 65

func isWeekday*(v: Visitor): bool {.raises: [].} = v.weekday < 5

func isDaytimeStudent*(v: Visitor): bool {.raises: [].} =
  v.isStudent and v.age < 26 and v.hour < 17

func isEvening*(v: Visitor): bool {.raises: [].} = v.hour >= 20

func tierOf*(v: Visitor): Tier {.raises: [].} =
  ## After: the rules read in priority order, first match wins.
  if v.isChild or (v.isSenior and v.isWeekday): tFree
  elif v.isDaytimeStudent or v.isEvening or v.isSenior: tReduced
  else: tFull

func priceOf*(t: Tier): int {.raises: [].} =
  case t
  of tFree: 0
  of tReduced: ReducedPrice
  of tFull: FullPrice

func price*(v: Visitor): int {.raises: [].} = v.tierOf.priceOf
