## Sorting the catalog into core / adjacent / out (NCK-CAT-05). Rules only; hand decisions go in
## catalog/overrides.json and win over the rules.

import std/[strutils, unicode]
import ./model

type Relevance* = enum
  core = "core" ## read for concepts (algorithms, data structures, patterns, functional programming)
  adjacent = "adjacent" ## kept in the catalog, not read in this round
  outOfScope = "out" ## screencasts, playgrounds, cheat sheets

const
  ## Matched against every heading of a listing's section path, lower-cased. Several languages,
  ## because the lists are in many (the English words also match most Latin-script headings).
  SectionKeywords* = [
    "algorithm", "data structure", "design pattern", "patterns", "software architecture",
    "functional programming", "computer science", "theoretical", "theory of computation",
    "compiler", "competitive programming", "parallel programming", "concurrency", "type theory",
    "programming language theory", "formal method",
    "haskell", "ocaml", "standard ml", "scheme", "racket", "lisp", "clojure", "erlang", "elixir",
    "f#", "elm", "purescript", "idris", "agda", "coq", "rocq", "lean", "nim", "scala", "lambda",
    "algoritm", "algorithmen", "algorithmes", "алгоритм", "структур", "entwurfsmuster",
    "patrones", "padrões", "patrons", "funcional", "funktional", "fonctionnelle", "функциональн",
    "アルゴリズム", "データ構造", "デザインパターン", "関数型", "コンパイラ",
    "算法", "数据结构", "设计模式", "函数式", "编译"]
  ## Matched against the title, for entries under a general heading.
  TitleKeywords* = ["algorithm", "data structure", "design pattern", "pattern language",
    "functional programming", "purely functional", "functional data", "type theory", "lambda calculus",
    "アルゴリズム", "データ構造", "デザインパターン", "関数型", "算法", "数据结构", "设计模式"]
  OutFiles* = ["free-programming-cheatsheets.md", "free-programming-playgrounds"]

func hasWord(low, w: string): bool {.raises: [].} =
  ## `w` occurs in `low` starting at a word boundary; a keyword of four bytes or fewer ("nim",
  ## "lean", "elm") must also end at one, so "animation" and "clean code" do not match.
  ## Non-ASCII keywords match anywhere (CJK has no spaces between words).
  if not w.allCharsInSet({'\0'..'\x7f'}):
    return w in low
  var i = low.find(w)
  while i >= 0:
    let startOk = i == 0 or low[i - 1] notin Letters
    let stop = i + w.len
    let endOk = w.len > 4 or stop >= low.len or low[stop] notin Letters
    if startOk and endOk: return true
    i = low.find(w, i + 1)

func containsAny(s: string; words: openArray[string]): bool {.raises: [].} =
  let low = unicode.toLower(s)
  for w in words:
    if hasWord(low, w): return true

func isOutListing(l: Listing): bool {.raises: [].} =
  if l.origin != oFpb: return false
  if l.file.startsWith("casts/"): return true
  for f in OutFiles:
    if f in l.file: return true

func classify*(s: Source): Relevance {.raises: [].} =
  ## The most relevant class any of the source's listings earns.
  ## Hillside listings are all core: the whole site is about patterns.
  result = outOfScope
  for l in s.listings:
    var r: Relevance
    if l.origin == oHillside and l.depth == 1:
      r = core
    elif l.depth == 2:
      r = if containsAny(s.title, TitleKeywords) or containsAny(s.title, ["pattern"]): core
          else: adjacent
    elif isOutListing(l):
      r = outOfScope
    else:
      var hit = containsAny(s.title, TitleKeywords)
      for h in l.section:
        if containsAny(h, SectionKeywords): hit = true
      r = if hit: core else: adjacent
    if ord(r) < ord(result): result = r
