## Factory Method as a proc value: the step that creates the product is a parameter.
##
## The OO pattern lets a subclass override `createX()` so that a shared algorithm can work with a
## product it does not know. In Nim the shared algorithm (`publish`) takes the creating step as
## an `ExporterFactory` value; no base class is needed. Use it when one routine must be reusable
## with several ways to make its collaborator and the choice is made by the caller.

import std/strutils
import nimcs/fp/result

type
  Format* = enum
    fmtText, fmtMarkdown, fmtHtml

  Doc* = object
    title*: string
    paras*: seq[string]

  Render* = proc(d: Doc): string {.noSideEffect, raises: [].}

  Exporter* = object
    ext*: string
    render*: Render

  ExporterFactory* = proc(f: Format): Result[Exporter, string] {.noSideEffect, raises: [].}

  PublishedFile* = object
    name*: string
    body*: string

func renderText(d: Doc): string {.raises: [].} =
  result = d.title & "\n"
  for p in d.paras:
    result.add("\n" & p)

func renderMarkdown(d: Doc): string {.raises: [].} =
  result = "# " & d.title & "\n"
  for p in d.paras:
    result.add("\n" & p & "\n")

func escapeHtml(s: string): string {.raises: [].} =
  for c in s:
    case c
    of '&': result.add("&amp;")
    of '<': result.add("&lt;")
    of '>': result.add("&gt;")
    of '"': result.add("&quot;")
    of '\'': result.add("&#39;")
    else: result.add(c)

func renderHtml(d: Doc): string {.raises: [].} =
  ## Content is escaped; the text and markdown renderers pass content through verbatim because
  ## their output is not interpreted as markup by this module.
  result = "<h1>" & escapeHtml(d.title) & "</h1>"
  for p in d.paras:
    result.add("<p>" & escapeHtml(p) & "</p>")

func standardFactory*(f: Format): Result[Exporter, string] {.raises: [].} =
  ## Knows every `Format`.
  case f
  of fmtText: ok(Exporter(ext: "txt", render: renderText), string)
  of fmtMarkdown: ok(Exporter(ext: "md", render: renderMarkdown), string)
  of fmtHtml: ok(Exporter(ext: "html", render: renderHtml), string)

func textOnlyFactory*(f: Format): Result[Exporter, string] {.raises: [].} =
  ## A second factory: refuses everything except plain text.
  case f
  of fmtText: standardFactory(f)
  of fmtMarkdown, fmtHtml: err(Exporter, "unsupported format")

const MaxTitleLen = 100

func safeTitle(t: string): bool {.raises: [].} =
  ## A title becomes a file name, so it must not be able to leave its directory or hide control
  ## characters: no path separators, no `..`, no `:`, no control characters, no leading or
  ## trailing `.` (hidden file, `a..txt`), 1 to 100 bytes.
  if t.len == 0 or t.len > MaxTitleLen or ".." in t or t[0] == '.' or t[^1] == '.':
    return false
  for c in t:
    if c in {'/', '\\', ':'} or c < ' ' or c == '\127':
      return false
  true

func publish*(d: Doc; make: ExporterFactory; f: Format): Result[PublishedFile, string] {.raises: [].} =
  ## The shared algorithm: ask the factory for an exporter, then use it. It never names a
  ## concrete exporter. An unsafe title is refused with "invalid title" before the factory is asked.
  let made = make(f)
  if not safeTitle(d.title):
    err(PublishedFile, "invalid title")
  elif made.isOk:
    ok(PublishedFile(name: d.title & "." & made.value.ext, body: made.value.render(d)), string)
  else:
    err(PublishedFile, made.error)
