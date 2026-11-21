## Layered architecture: modules in layers, imports in one direction, rules in the lowest layer.
##
## The program is a task board driven by text commands, split into three layers that live in
## `layered_architecture/`: `domain` (rules, imports nothing of the program), `service` (parsing
## and replies, imports `domain`) and `shell` (the effects, imports `service` and `domain`). A
## module may import a layer below it and never one above or beside it; with this rule the domain
## can be tested with no parser and the service with no terminal, and a cycle cannot form. This
## file is the composition root: it re-exports the layers and keeps `tangledBefore`, the same
## behaviour written as one routine that parses, decides and formats together. Use layers when a
## program has rules, a protocol and effects that change at different rates; skip them for a
## script. The functional-core pattern (`functional_core`) is the same split seen from the effects.

import nimcs/patterns/layered_architecture/[domain, service, shell]
export domain, service, shell

func tangledBefore*(lines: openArray[string]): seq[string] {.raises: [].} =
  ## Before: one routine that splits the line, owns the task lists and builds each reply.
  var titles: seq[string]
  var done: seq[bool]
  for line in lines:
    var verb = line
    var rest = ""
    for i in 0 ..< line.len:
      if line[i] == ' ':
        verb = line[0 ..< i]
        rest = line[i + 1 .. ^1]
        break
    if verb == "add":
      if rest.len == 0:
        result.add "error: empty title"
      else:
        titles.add rest
        done.add false
        result.add "added " & $titles.len & ": " & rest
    elif verb == "done":
      var n = 0
      var good = rest.len > 0 and rest.len <= 6
      for c in rest:
        if c < '0' or c > '9': good = false
        else: n = n * 10 + (ord(c) - ord('0'))
      if not good:
        result.add "error: bad id"
      elif n < 1 or n > titles.len:
        result.add "error: no task " & $n
      else:
        done[n - 1] = true
        result.add "done " & $n
    elif verb == "list":
      if titles.len == 0:
        result.add "(empty)"
      else:
        var s = ""
        for i in 0 ..< titles.len:
          if i > 0: s.add "; "
          s.add $(i + 1) & (if done[i]: " [x] " else: " [ ] ") & titles[i]
        result.add s
    else:
      result.add "error: unknown command"
