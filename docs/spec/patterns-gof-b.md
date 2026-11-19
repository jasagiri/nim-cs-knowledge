# GoF behavioral patterns (functional Nim)

Spec table for `src/nimcs/patterns/{strategy,command,interpreter,iterator_pattern,mediator,memento,observer,state,chain_of_responsibility,template_method,visitor}.nim`.

| ID | Concept | Statement |
|---|---|---|
| GOF-STRATEGY-01 | strategy | Checking out items with `noDiscount` yields exactly the sum of the item prices. |
| GOF-STRATEGY-02 | strategy | `percentOff` and `flatOff` never return a negative price and never a price above the input, for any amount or percentage (out-of-range arguments are clamped). |
| GOF-STRATEGY-03 | strategy | `a.then(b)(x) == b(a(x))` for any two rules and price. |
| GOF-STRATEGY-04 | strategy | `cheapest` is no more than the price under each rule and no more than the unchanged price; with no rules it returns the price. |
| GOF-STRATEGY-05 | strategy | Passing the rule as a proc value (`checkout`) and as a generic parameter (`total2`) gives the same total. |
| GOF-STRATEGY-06 | strategy | `cents(n)` is `none` for negative `n` and `some` otherwise. |
| GOF-STRATEGY-07 | strategy | `percentOff` rounds the discount down: 10 percent off 1999 is 1800. |
| GOF-STRATEGY-08 | strategy | For prices up to `high(int)`, `percentOff` and `flatOff` stay within `0 .. price` without overflow, and `checkout` saturates at `high(int)` instead of overflowing (items are non-negative). |
| GOF-COMMAND-01 | command | For any valid command, executing it and then undoing it restores the original text. |
| GOF-COMMAND-02 | command | A command outside the document fails with `eeOutOfRange` and leaves the editor value usable and unchanged. |
| GOF-COMMAND-03 | command | Replaying a command log is deterministic, and `replay` agrees with running the commands one by one through `exec`. |
| GOF-COMMAND-04 | command | Undoing every successful edit, newest first, returns the original text with an empty undo stack. |
| GOF-COMMAND-05 | command | Undo followed by redo restores the editor exactly as it was after the edit. |
| GOF-COMMAND-06 | command | Executing a new command clears the redo stack. |
| GOF-COMMAND-07 | command | Undo on an editor with no history fails with `eeNothingToUndo`. |
| GOF-COMMAND-08 | command | Concrete insert and delete commands give the expected texts and undo through two steps. |
| GOF-COMMAND-09 | command | Positions are byte offsets; a position or range end inside a multi-byte UTF-8 character fails with `eeNotCharBoundary`, inserted invalid UTF-8 fails with `eeInvalidUtf8`, and accepted edits keep a valid document valid and undo restores it. |
| GOF-INTERP-01 | interpreter | `eval` computes the arithmetic value of numbers, variables, negation, addition, multiplication and truncating division. |
| GOF-INTERP-02 | interpreter | `eval` reports the first failure in reading order (left operand first): unbound variable, division by zero, or a value beyond `+-Limit`. |
| GOF-INTERP-03 | interpreter | For any expression, `eval(fold(e)) == eval(e)`, results and errors included, for any literals (also beyond `+-Limit`, `low(int)`, `high(int)`). |
| GOF-INTERP-04 | interpreter | `fold` is idempotent: `fold(fold(e))` is structurally equal to `fold(e)`. |
| GOF-INTERP-05 | interpreter | `fold` never increases the number of nodes. |
| GOF-INTERP-06 | interpreter | An expression without variables that evaluates successfully folds to a single number equal to its value. |
| GOF-INTERP-07 | interpreter | A constant subtree that would fail is kept by `fold`, so the error is still reported. |
| GOF-INTERP-08 | interpreter | `show` is injective: `show(a) == show(b)` exactly when `a` and `b` are structurally equal (variable names are validated by `variable`, so no name can imitate an operator or parenthesis). |
| GOF-INTERP-09 | interpreter | `variable(name)` is `ok` exactly when `name` is an identifier (a letter or underscore, then letters, digits and underscores) and `err(veBadName)` otherwise; the `Expr` fields are private, so code outside the module cannot build a node (for example a variable with a bad name) by naming the fields. |
| GOF-ITER-01 | iterator_pattern | `items` yields the inserted values in ascending order, each once. |
| GOF-ITER-02 | iterator_pattern | Draining a `Cursor` yields exactly what `items` yields. |
| GOF-ITER-03 | iterator_pattern | A cursor is a value: calling `next` twice on the same cursor gives the same element and equal continuations. |
| GOF-ITER-04 | iterator_pattern | Iterating the same tree twice yields the same sequence. |
| GOF-ITER-05 | iterator_pattern | `mergeUnion` of two trees is the ascending union of their elements without repeats. |
| GOF-ITER-06 | iterator_pattern | `insert` returns a new tree and leaves the old tree's traversal unchanged. |
| GOF-ITER-07 | iterator_pattern | An empty tree yields nothing, its cursor ends at once, and merging empty trees gives an empty result. |
| GOF-MEDIATOR-01 | mediator | A `say` is delivered once to every member except the sender, and does not change the room. |
| GOF-MEDIATOR-02 | mediator | Any message from a non-member fails with `reNotMember`. |
| GOF-MEDIATOR-03 | mediator | A whisper is delivered to exactly its recipient; an unknown recipient fails with `reNoSuchRecipient` and a whisper to oneself with `reSelfWhisper`. |
| GOF-MEDIATOR-04 | mediator | For any message log, every delivery goes to a member of the room before the message and never to the sender. |
| GOF-MEDIATOR-05 | mediator | Running the same log twice gives identical reports. |
| GOF-MEDIATOR-06 | mediator | The member list stays sorted without duplicates, and joining twice fails with `reAlreadyMember`. |
| GOF-MEDIATOR-07 | mediator | A rejected message in a log has no effect on the room or deliveries and is listed in `rejected` with its index. |
| GOF-MEDIATOR-08 | mediator | Leaving removes the member and tells the others. |
| GOF-MEMENTO-01 | memento | A value saved with `let` is unaffected by later changes to the original, for objects whose fields are values (copied on assignment). Data reached through a `ref` field is shared, see GOF-MEMENTO-08. |
| GOF-MEMENTO-08 | memento | Copying an object with a `ref` field shares the referenced data (a later change through the original shows in the copy); a snapshot that must survive builds a fresh value for that data. |
| GOF-MEMENTO-02 | memento | Recording a value and undoing returns the previous present with the same history and one value to redo. |
| GOF-MEMENTO-03 | memento | Undo followed by redo returns the timeline unchanged. |
| GOF-MEMENTO-04 | memento | The past never exceeds the capacity (minimum 1) and keeps the newest values. |
| GOF-MEMENTO-05 | memento | Recording a value clears the redo side. |
| GOF-MEMENTO-06 | memento | Undo and redo on a fresh timeline are `none`. |
| GOF-MEMENTO-07 | memento | Undoing a timeline does not change the timeline it was derived from. |
| GOF-OBSERVER-01 | observer | Replaying one event log twice from the same state gives equal states. |
| GOF-OBSERVER-02 | observer | `publish` equals folding the subscribers over the state in subscription order. |
| GOF-OBSERVER-03 | observer | With no subscribers, publishing leaves the state unchanged. |
| GOF-OBSERVER-04 | observer | `unsubscribe` removes exactly that subscriber, keeps the order of the rest, leaves the old bus intact, and ignores unknown ids. |
| GOF-OBSERVER-05 | observer | Replaying two logs in two steps equals replaying their concatenation. |
| GOF-OBSERVER-06 | observer | Subscribing with an id that already exists replaces the subscriber in place; nothing runs twice. |
| GOF-OBSERVER-07 | observer | The ticker example's four subscribers produce the expected latest prices, high, count and audit. |
| GOF-STATE-01 | state | For any starting stock and event sequence, money conservation and non-negative counts hold after every accepted step. |
| GOF-STATE-02 | state | A rejected event leaves the machine unchanged; `run` lists each rejection with its index and agrees with stepping by hand. |
| GOF-STATE-03 | state | Running the same events from the same machine twice gives equal reports. |
| GOF-STATE-04 | state | 100 plus 50 yen then select sells one item and leaves 30 yen change in the tray; collecting returns it. |
| GOF-STATE-05 | state | Selecting with less than the price fails with `veInsufficient` and keeps the credit. |
| GOF-STATE-06 | state | While change waits in the tray, only collect is accepted. |
| GOF-STATE-07 | state | A sold-out idle machine refuses coins with `veSoldOut` until restocked. |
| GOF-STATE-08 | state | A refund returns the whole credit and sells nothing. |
| GOF-STATE-09 | state | Unknown coins, bad restock counts, collect without change and select without credit are refused with their own errors. |
| GOF-CHAIN-01 | chain_of_responsibility | `firstSome` returns the answer of the first handler that answers. |
| GOF-CHAIN-02 | chain_of_responsibility | An empty chain or one in which no handler accepts yields an `Unhandled` error. |
| GOF-CHAIN-03 | chain_of_responsibility | Appending handlers never changes an answer the chain already gave. |
| GOF-CHAIN-04 | chain_of_responsibility | In the authority chain the lowest authority whose limit covers the amount approves (limits inclusive). |
| GOF-CHAIN-05 | chain_of_responsibility | `orElse` is associative. |
| GOF-CHAIN-06 | chain_of_responsibility | `never` is the identity of `orElse` on both sides. |
| GOF-CHAIN-07 | chain_of_responsibility | Handling the same request twice gives the same answer. |
| GOF-CHAIN-08 | chain_of_responsibility | A handler restricted to one category passes requests of other categories on to the next handler. |
| GOF-TEMPLATE-01 | template_method | The first line of a rendered report is the header and the last the footer, for any items. |
| GOF-TEMPLATE-02 | template_method | The report has one row per item the keep step accepts, and header and footer see that count. |
| GOF-TEMPLATE-03 | template_method | Replacing only the footer step changes only the last line. |
| GOF-TEMPLATE-04 | template_method | Rendering is deterministic. |
| GOF-TEMPLATE-05 | template_method | The default and CSV variants share the skeleton and produce the documented texts, also for no items. |
| GOF-TEMPLATE-06 | template_method | Row indices count kept items from zero. |
| GOF-TEMPLATE-07 | template_method | The CSV variant quotes fields per RFC 4180 (`csvField`): any list of strings, including commas, quotes and newlines, is recovered field by field by a CSV reader. |
| GOF-VISITOR-01 | visitor | Leaf count and rendering computed by a direct `case` equal the same computed by a `ShapeFold` through `accept`. |
| GOF-VISITOR-02 | visitor | Translating a shape moves its bounds by the same offset (and an empty group stays empty). |
| GOF-VISITOR-03 | visitor | Translation does not change leaf count or footprint. |
| GOF-VISITOR-04 | visitor | Translating twice equals one translation by the summed offset. |
| GOF-VISITOR-05 | visitor | Translating by zero returns an equal shape. |
| GOF-VISITOR-06 | visitor | A group's bounds contain the bounds of each child. |
| GOF-VISITOR-07 | visitor | Concrete shapes give the documented bounds, footprint, leaf count and rendering; negative sizes clamp to zero. |
