## Extract type: fields that always travel together become a value type that guards its own rules.
##
## `amount: int` and `currency: string` appear side by side in every signature of the loose code
## (`addLoose`), so every caller must remember that two amounts may be added only in the same
## currency, that the code is one of a few known ones, and that cents are integers. Extracting
## `Money` moves those rules into one smart constructor (`initMoney`) and one operation (`plus`)
## that returns a `Result`. The values for which the loose code was right behave the same
## (tested); the value for which it was silently wrong, adding yen to dollars, becomes an error
## the caller has to look at. Use it when two or more fields are passed together in three or more
## places, or when a rule mentions them together.

import nimcs/fp/result
export result

type
  Currency* = enum
    cJpy = "JPY", cUsd = "USD", cEur = "EUR"

  MoneyError* = enum
    meUnknownCurrency, meCurrencyMismatch, meNegative

  Money* = object
    ## `minor` is in the smallest unit of `currency` and is never negative (see `initMoney`).
    minor: int
    currency: Currency

func parseCurrency*(code: string): Result[Currency, MoneyError] {.raises: [].} =
  for c in Currency:
    if $c == code:
      return ok(c, MoneyError)
  err(Currency, meUnknownCurrency)

func initMoney*(minor: int; code: string): Result[Money, MoneyError] {.raises: [].} =
  ## The one door: a known code and a non-negative amount, or the reason it is refused.
  let c = parseCurrency(code)
  if c.isErr:
    err(Money, c.error)
  elif minor < 0:
    err(Money, meNegative)
  else:
    ok(Money(minor: minor, currency: c.value), MoneyError)

func minor*(m: Money): int {.raises: [].} = m.minor

func currency*(m: Money): Currency {.raises: [].} = m.currency

func plus*(a, b: Money): Result[Money, MoneyError] {.raises: [].} =
  ## Amounts add only in one currency; a mismatch is an error, not a wrong number.
  if a.currency != b.currency:
    err(Money, meCurrencyMismatch)
  else:
    ok(Money(minor: a.minor + b.minor, currency: a.currency), MoneyError)

func `==`*(a, b: Money): bool {.raises: [].} =
  a.minor == b.minor and a.currency == b.currency

func addLoose*(aMinor: int; aCode: string; bMinor: int; bCode: string): (int, string) {.raises: [].} =
  ## Before: the two fields of each amount travel apart; nothing stops yen being added to dollars,
  ## and the result takes the first code whatever the second was.
  (aMinor + bMinor, aCode)
