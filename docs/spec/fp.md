# Spec: functional foundations (`src/nimcs/fp/`)

Each row is a law or an externally visible behaviour; each ID has at least one test tagged `# SPEC: <ID>`
in `tests/test_fp_<concept>.nim`.

| ID | Concept | Statement |
|---|---|---|
| FP-RESULT-01 | result | Functor laws: `r.map(identity) == r` and `r.map(f).map(g) == r.map(x => g(f(x)))`. |
| FP-RESULT-02 | result | Railway: an error short-circuits `flatMap`; the first error in the chain is the one reported. |
| FP-RESULT-03 | result | Monad laws for `flatMap` with `ok`: left identity, right identity, associativity. |
| FP-RESULT-04 | result | `mapErr` changes only the error side; an `ok` passes through untouched. |
| FP-RESULT-05 | result | `valueOr` returns the value of an `ok` and the fallback for an error. |
| FP-RESULT-06 | result | `==` compares the case, then the value or the error. |
| FP-OPTIONOPS-01 | option_ops | `okOr` turns `some` into `ok` and `none` into the given error. |
| FP-OPTIONOPS-02 | option_ops | `toOption` forgets the error; `ok(x).toOption.okOr(e) == ok(x)`. |
| FP-OPTIONOPS-03 | option_ops | `orElse` is left-biased, associative, with `none` as identity. |
| FP-OPTIONOPS-04 | option_ops | `both(a, b)` is `some` of the pair exactly when both are `some`. |
| FP-OPTIONOPS-05 | option_ops | `sequence` is `some` of all values in order when all are present, else `none`. |
| FP-OPTIONOPS-06 | option_ops | `catSome` keeps the present values in order. |
| FP-OPTIONOPS-07 | option_ops | `firstSome` is the head of `catSome`, or `none` when that is empty. |
| FP-OPTIONOPS-08 | option_ops | The standard `map`, `flatMap`, `filter` and `get(default)` leave `none` as `none`; `map` with identity is the identity. |
| FP-FOLD-01 | fold | `foldLeft` visits left to right; an empty input gives `init`; with `+` from 0 it is the sum. |
| FP-FOLD-02 | fold | Split law: `foldLeft(a & b, i, f) == foldLeft(b, foldLeft(a, i, f), f)`. |
| FP-FOLD-03 | fold | `foldRight` with cons and `foldLeft` with snoc rebuild the input. |
| FP-FOLD-04 | fold | `foldLeft` and `foldRight` agree for an associative commutative step and differ for subtraction. |
| FP-FOLD-05 | fold | `scan` has `len + 1` elements, starts at `init`, ends at the `foldLeft` result, each element is one step from the last. |
| FP-FOLD-06 | fold | `unfold` stops at `none` and never produces more than `limit` elements. |
| FP-FOLD-07 | fold | Length, map, filter and reverse are expressible as folds and equal the standard versions. |
| FP-IMMUTABLEUPDATE-01 | immutable_update | `added` returns a new cart (a `Result`); the cart it was given is unchanged and the total grows by `qty * unitCents`. |
| FP-IMMUTABLEUPDATE-02 | immutable_update | Every version of a chain of updates stays readable with its own contents. |
| FP-IMMUTABLEUPDATE-03 | immutable_update | `removed` and `withQty` are idempotent. |
| FP-IMMUTABLEUPDATE-04 | immutable_update | Adding an existing `sku` at the same price sums the quantity; a cart never holds two entries for one `sku`. |
| FP-IMMUTABLEUPDATE-05 | immutable_update | Assigning an object copies it: changing the copy never changes the original. |
| FP-IMMUTABLEUPDATE-06 | immutable_update | Adding a `sku` already present at another unit price is `priceConflict`; the cart is unchanged. |
| FP-IMMUTABLEUPDATE-07 | immutable_update | A quantity below 1 in `added` or `withQty` is `badQuantity`. |
| FP-COMPOSE-01 | compose | `compose(f, g)(x) == f(g(x))` and `andThen(f, g)(x) == g(f(x))`. |
| FP-COMPOSE-02 | compose | Composition is associative. |
| FP-COMPOSE-03 | compose | `identity` is a left and right unit of composition. |
| FP-COMPOSE-04 | compose | `andThen(f, g)` and `compose(g, f)` are the same function. |
| FP-COMPOSE-05 | compose | `composeAll` runs the steps first to last; an empty list is `identity`. |
| FP-COMPOSE-06 | compose | Map fusion: `xs.map(g).map(f) == xs.map(compose(f, g))`. |
| FP-LAZYSTREAM-01 | lazy_stream | `fromSeq(xs).toSeq(n)` is the first `n` elements of `xs`. |
| FP-LAZYSTREAM-02 | lazy_stream | Stream `map` and `filter` give what the eager versions give. |
| FP-LAZYSTREAM-03 | lazy_stream | `take(n)` of an infinite stream has exactly `n` elements. |
| FP-LAZYSTREAM-04 | lazy_stream | `filter`, `map` and `takeWhile` on an infinite stream terminate once cut, and `iterate` never runs its step for an element that is not pulled (a step that would overflow past the prefix is not called). |
| FP-LAZYSTREAM-05 | lazy_stream | A stream can be walked twice with the same result. |
| FP-LAZYSTREAM-06 | lazy_stream | `take(n).take(m) == take(min(n, m))`. |
| FP-LAZYSTREAM-07 | lazy_stream | `toSeq(limit)` never returns more than `limit` elements. |
| FP-LAZYSTREAM-08 | lazy_stream | A `fromSeq` stream of a long sequence yields every element in order. |
| FP-ADT-01 | adt | `eval` gives the arithmetic value of each shape. |
| FP-ADT-02 | adt | Division by zero and `int` overflow are `EvalError` values; the left operand's error is reported first. |
| FP-ADT-03 | adt | `eval(simplify(e)) == eval(e)`, including at `low(int)` and `high(int)`; `--x` is not rewritten unless `x` is a number. |
| FP-ADT-04 | adt | `simplify` is idempotent and removes `0 + x`, `x * 1`, `x / 1` and folds constants. |
| FP-ADT-05 | adt | `size(simplify(e)) <= size(e)`. |
| FP-ADT-06 | adt | `show` is fully parenthesised and injective on trees (`neg(1)` and `-1` print differently); `size` counts nodes. |
| FP-ADT-07 | adt | `==` on `Expr` is structural, not by address. |
| FP-SMARTCONSTRUCTOR-01 | smart_constructor | `parseUsername` accepts exactly 3 to 16 characters of `a-z 0-9 _` and keeps the text. |
| FP-SMARTCONSTRUCTOR-02 | smart_constructor | A bad username is `tooShort`, `tooLong` or `badCharacter`, as the case may be. |
| FP-SMARTCONSTRUCTOR-03 | smart_constructor | Parsing is idempotent: parsing the value of a parsed username gives it back; input is trimmed and lower-cased. |
| FP-SMARTCONSTRUCTOR-04 | smart_constructor | `parseQuantity(n)` is `ok` exactly for 1 to 1000 and the value round-trips; otherwise `outOfRange`. |
| FP-SMARTCONSTRUCTOR-05 | smart_constructor | `parseQuantityText` parses whole numbers, ignores surrounding spaces, and reports other text as `notANumber`. |
| FP-SMARTCONSTRUCTOR-06 | smart_constructor | `plus` stays in range or is `outOfRange`; it never wraps. |
| FP-SMARTCONSTRUCTOR-07 | smart_constructor | `parseOrder` reports the error of the first failing field. |
| FP-SMARTCONSTRUCTOR-08 | smart_constructor | The sealed types cannot be forged (private field), left unset (`requiresInit`) or mixed with their base type outside the module. |
| FP-IDEMPOTENCE-01 | idempotence | `normalizeSpaces(normalizeSpaces(s)) == normalizeSpaces(s)`. |
| FP-IDEMPOTENCE-02 | idempotence | `setInsert` is idempotent and keeps the set sorted, unique, containing `x`. |
| FP-IDEMPOTENCE-03 | idempotence | `upsertByKey` is idempotent and leaves exactly one entry for the key, even if the input held duplicates. |
| FP-IDEMPOTENCE-04 | idempotence | `apply` of the same command (same key, same amount) again returns the same ledger. |
| FP-IDEMPOTENCE-05 | idempotence | Replaying a whole batch after itself gives the ledger of a single run. |
| FP-IDEMPOTENCE-06 | idempotence | Commands with distinct keys commute: every permutation gives the same ledger. |
| FP-IDEMPOTENCE-07 | idempotence | Determinism does not imply idempotence: `x + 1` fails the law, and the checker finds it. |
| FP-IDEMPOTENCE-08 | idempotence | `abs`, `clamp` and `sorted` are idempotent. |
| FP-IDEMPOTENCE-09 | idempotence | `apply` of a used key with a different amount is `keyConflict` (a `Result` error); the ledger is unchanged. |
| FP-MONOID-01 | monoid | Sum, product, max and min on `int` satisfy identity and associativity (no overflow). |
| FP-MONOID-02 | monoid | String and sequence concatenation satisfy identity and associativity. |
| FP-MONOID-03 | monoid | `mapMonoid(m)` satisfies identity and associativity when `m` does. |
| FP-MONOID-04 | monoid | `mconcat` of nothing is `empty`, and `mconcat(a & b) == combine(mconcat(a), mconcat(b))`. |
| FP-MONOID-05 | monoid | `foldMap(xs, f) == mconcat(xs.map(f))`. |
| FP-MONOID-06 | monoid | String concatenation is not commutative. |
| FP-MONOID-07 | monoid | Merging tables with a sum monoid adds colliding keys and is commutative. |
