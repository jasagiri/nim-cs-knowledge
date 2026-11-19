## Idempotent command: the same command with the same key is applied once, however often it arrives.
##
## Networks deliver at least once, so a client that did not hear back sends the command again.
## Each command carries a key chosen by the client. The ledger stores, for every key it has
## seen, the command and the response it produced; a repeat of the same command returns the
## stored response and changes nothing, and a different command under a used key is a conflict.
## `handle` is a pure function from (ledger, command) to (ledger, response), so "applying twice
## equals applying once" is a property of a function, not a hope about a server. Use it for any
## operation a client may retry (payments, orders, sign-ups). In production the entry list
## would be a keyed table with an expiry; the list keeps the example short and ordered.

type
  CommandKind* = enum
    ckDeposit, ckWithdraw

  Command* = object
    key*: string
    kind*: CommandKind
    amount*: int

  ResponseKind* = enum
    rkAccepted, rkInsufficientFunds, rkInvalidAmount, rkKeyConflict

  Response* = object
    ## `balance` is the balance the command left (accepted) or found (every refusal that was
    ## stored); for a conflict it is the current balance.
    kind*: ResponseKind
    balance*: int

  Entry* = object
    cmd*: Command
    response*: Response

  Ledger* = object
    balance*: int
    entries*: seq[Entry]   ## in order of first arrival; one per key

  Handled* = tuple[ledger: Ledger, response: Response]

func initLedger*(): Ledger {.raises: [].} = Ledger(balance: 0, entries: @[])

func decideNew(l: Ledger; cmd: Command): Handled {.raises: [].} =
  ## First arrival of a key: decide, then record the outcome under the key.
  var balance = l.balance
  var kind = rkAccepted
  if cmd.amount <= 0:
    kind = rkInvalidAmount
  else:
    case cmd.kind
    of ckDeposit:
      balance += cmd.amount
    of ckWithdraw:
      if balance < cmd.amount: kind = rkInsufficientFunds
      else: balance -= cmd.amount
  let response = Response(kind: kind, balance: balance)
  var entries = l.entries
  entries.add Entry(cmd: cmd, response: response)
  (ledger: Ledger(balance: balance, entries: entries), response: response)

func handle*(l: Ledger; cmd: Command): Handled {.raises: [].} =
  ## A key seen before returns its stored response and the same ledger when the command is
  ## identical, and `rkKeyConflict` (ledger unchanged, nothing stored) when it is not. A new key
  ## is decided once; refusals are stored too, so a retry sees the same refusal even if the
  ## balance would now allow the command.
  for e in l.entries:
    if e.cmd.key == cmd.key:
      if e.cmd == cmd:
        return (ledger: l, response: e.response)
      return (ledger: l, response: Response(kind: rkKeyConflict, balance: l.balance))
  decideNew(l, cmd)
