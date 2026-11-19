# Spec: GoF creational and structural patterns in functional Nim

Modules in `src/nimcs/patterns/`; tests in `tests/test_patterns_<module>.nim`.

| ID | Concept | Statement |
|---|---|---|
| GOF-FACTORYMETHOD-01 | factory_method | For any document and format, `publish(d, standardFactory, f)` produces the file named `title.ext` whose body is the exporter's own render of `d`. |
| GOF-FACTORYMETHOD-02 | factory_method | For a safe title, when the factory refuses a format, `publish` returns that factory's error unchanged and no file. |
| GOF-FACTORYMETHOD-03 | factory_method | Passing a different factory changes the product (extension and body) without any change to `publish`. |
| GOF-FACTORYMETHOD-04 | factory_method | The html exporter escapes `&`, `<`, `>`, `"` and `'` in title and paragraphs, so the only markup in its body is its own tags. The text and markdown exporters pass content through verbatim (stated, not escaped). |
| GOF-FACTORYMETHOD-05 | factory_method | `publish` refuses with "invalid title" any title that is empty, longer than 100 bytes, contains `..`, `/`, `\`, `:` or a control character, or starts or ends with `.`; a published name never contains a path separator or control character. |
| GOF-ABSTRACTFACTORY-01 | abstract_factory | Every product made by `kitFor(t)` carries the family of `t`, for any label and state. |
| GOF-ABSTRACTFACTORY-02 | abstract_factory | A client routine given a kit (`loginForm`) returns only widgets of that kit's family. |
| GOF-ABSTRACTFACTORY-03 | abstract_factory | Two different themes render the same client input differently, and each theme renders it the same way every time. |
| GOF-BUILDER-01 | builder | A builder setter returns a changed copy; the builder it was called on still builds what it built before. |
| GOF-BUILDER-02 | builder | `build` rejects an empty host, a port outside 1..65535, TLS without a certificate, and fewer than one worker, each with its own error; the first failing check in that order is the one reported. |
| GOF-BUILDER-03 | builder | For any valid settings, `build` succeeds and the configuration holds exactly those settings. |
| GOF-BUILDER-04 | builder | Setters of different fields commute, and applying the same setter twice equals applying it once. |
| GOF-BUILDER-05 | builder | A builder that has not been given a host does not build, whatever else is set. |
| GOF-PROTOTYPE-01 | prototype | A copy equals its original, and changing the copy (`withHp`, `withTag`) leaves the original unchanged. |
| GOF-PROTOTYPE-02 | prototype | `instantiate` of a registered name returns a value equal to the prototype; instantiating twice gives equal values; an unknown name gives `none`. |
| GOF-PROTOTYPE-04 | prototype | Copying an object that has a `ref` field copies the reference: original and copy share the referenced data (documented caveat; value fields stay independent). |
| GOF-PROTOTYPE-03 | prototype | `register` replaces an existing name instead of duplicating it, keeps other entries, and leaves the old registry unchanged. |
| GOF-SINGLETON-01 | singleton | `DefaultSettings` is a constant: deriving a changed copy with `withRetries` never alters it. |
| GOF-SINGLETON-02 | singleton | `stamp` with a fixed clock is deterministic and contains the clock's time and the message. |
| GOF-SINGLETON-03 | singleton | Two clocks coexist independently: stamps from clocks with different times differ, with equal times are equal. |
| GOF-ADAPTER-01 | adapter | For any minute of the day, `fromLegacy(toLegacy(m))` is `m`. |
| GOF-ADAPTER-02 | adapter | Malformed legacy strings are rejected with the specific error (length, separator, digit, range), never an exception. |
| GOF-ADAPTER-03 | adapter | `adaptAll` of a source equals mapping `fromLegacy` over its output, and stops at the first bad entry. |
| GOF-BRIDGE-01 | bridge | `draw` of a shape through a backend is exactly that backend's `line` primitive applied to each segment of `lower(shape)`, in order. |
| GOF-BRIDGE-02 | bridge | `drawAll` of a concatenation is the concatenation of the `drawAll`s, for every backend. |
| GOF-BRIDGE-03 | bridge | Shapes and backends vary independently through a fixed primitive (`line`): `lower` has no backend argument and yields a closed outline (4 segments for a rectangle, 8 for a circle), a backend defined outside the module draws every shape, and drawing a moved shape equals drawing the shifted segments. (Changed from the first version, whose backend had one primitive per shape kind and so was N x M.) |
| GOF-COMPOSITE-01 | composite | The total size of a tree is the sum of the sizes of its leaves. |
| GOF-COMPOSITE-02 | composite | `fileCount` equals the number of leaves, and `leafSizes` lists the leaves in left-to-right order. |
| GOF-COMPOSITE-03 | composite | Adding an empty directory does not change `totalSize` or `fileCount`; nesting a group of children in a directory does not change them either. |
| GOF-COMPOSITE-04 | composite | `depth` of a file is 0 and of a directory is one more than its deepest child. |
| GOF-DECORATOR-01 | decorator | `compose(a, b)` applied to a handler equals `a(b(h))`: the outer decorator's trace entries come first and last. |
| GOF-DECORATOR-02 | decorator | The identity decorator leaves a handler's behaviour unchanged. |
| GOF-DECORATOR-03 | decorator | `compose` is associative on observable behaviour, and `stack` of a list equals composing from the front. |
| GOF-DECORATOR-04 | decorator | An authorisation decorator answers 401 for a wrong token without running the inner handler, and is transparent for the right token. |
| GOF-FACADE-01 | facade | `summarize` counts words as the maximal runs of ASCII letters and digits, case-insensitively. |
| GOF-FACADE-02 | facade | `normalizeText` is idempotent. |
| GOF-FACADE-03 | facade | `summarize(t)` equals `summarize(normalizeText(t))`. |
| GOF-FACADE-04 | facade | A text without word characters summarises to zero words, no longest word and no top entries; `top` is ordered by count descending then word ascending and has at most `topN` entries. |
| GOF-FLYWEIGHT-01 | flyweight | Interning a string twice returns the same symbol and the same pool the second time (idempotent). |
| GOF-FLYWEIGHT-02 | flyweight | `resolve(intern(s))` is `s`. |
| GOF-FLYWEIGHT-03 | flyweight | Equal strings get equal symbols and different strings get different symbols. |
| GOF-FLYWEIGHT-05 | flyweight | `internAll` on any pool equals interning the items one by one (same pool, same symbols). |
| GOF-FLYWEIGHT-06 | flyweight | `internAll` of 20000 distinct strings takes under one second (it copies the pool once, not once per string). |
| GOF-FLYWEIGHT-04 | flyweight | The pool size is the number of distinct strings interned, and symbols are numbered by first appearance. |
| GOF-PROXY-01 | proxy | A protection proxy that allows every key behaves as the source. |
| GOF-PROXY-02 | proxy | A key the protection proxy denies yields `err(refDenied)`, distinguishable from an absent key (`ok(none)`), and the source is never asked. |
| GOF-PROXY-03 | proxy | `lookup` returns what the source returns (values, absences and refusals alike), and a repeated lookup leaves the cache unchanged. |
| GOF-PROXY-04 | proxy | After any sequence of lookups, `misses` equals the number of distinct keys looked up. |
| GOF-PROXY-05 | proxy | `asSource` of a cache answers every key exactly as the real source does (substitutable read-only view); `Cached` itself is not a `Source` because `lookup` threads state. |
