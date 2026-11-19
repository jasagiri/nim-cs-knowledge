## Prototype: with value semantics, copying is the default, and the pattern mostly disappears.
##
## The OO pattern clones an existing object to avoid re-creating it and to avoid depending on its
## class. In Nim an assignment already makes an independent deep copy of an `object` (including its
## `seq` and `string` fields), so "clone, then change" is `let b = a` plus a `with...` func. What
## remains useful is a named registry of template values (an immutable table of prototypes).
## Use the registry when callers pick a template by name; otherwise just copy.
##
## Caveat: the copy is deep only through value fields. A `ref` (or `ptr`, or a closure's captured
## state) inside the object is copied as a reference, so original and copy then share the referenced
## data. Keep templates free of `ref` fields, or hold such data in a value type.

import std/options

type
  Enemy* = object
    kind*: string
    hp*: int
    tags*: seq[string]

  Registry* = object
    entries: seq[(string, Enemy)]

func withHp*(e: Enemy; hp: int): Enemy {.raises: [].} =
  result = e
  result.hp = hp

func withTag*(e: Enemy; tag: string): Enemy {.raises: [].} =
  result = e
  result.tags.add(tag)

func initRegistry*(): Registry {.raises: [].} =
  Registry(entries: @[])

func register*(r: Registry; name: string; proto: Enemy): Registry {.raises: [].} =
  ## Returns a registry where `name` maps to `proto`; an earlier entry of the same name is replaced.
  result = Registry(entries: @[])
  var replaced = false
  for (n, e) in r.entries:
    if n == name:
      result.entries.add((n, proto))
      replaced = true
    else:
      result.entries.add((n, e))
  if not replaced:
    result.entries.add((name, proto))

func instantiate*(r: Registry; name: string): Option[Enemy] {.raises: [].} =
  ## A fresh, independent copy of the template, or `none`.
  for (n, e) in r.entries:
    if n == name:
      return some(e)
  none(Enemy)

func names*(r: Registry): seq[string] {.raises: [].} =
  for (n, _) in r.entries:
    result.add(n)
