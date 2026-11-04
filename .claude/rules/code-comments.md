---
paths:
  - "**/*.swift"
---

# Comments: the default is none

**Code should be self-documenting. A comment is a failure to express something
in code, and is a last resort.** Before writing one, try renaming the thing,
extracting a function whose name says it, or restructuring until the question
disappears. Most comments are answered by a better name.

## Earning a comment

Only three things survive. **If a comment is none of them, delete it.**

1. A constraint from outside the code — what CloudKit does, what SwiftData
   does. Nothing in the file can say it.
2. A decision whose alternative is invisible from the code.
3. A workaround, and what breaks without it.

"What this does", "what this parameter is", and anything a reader could work
out from the code are not on the list.

## Keep it brief

**Two lines per fact, not per comment.** A doc carrying four separate external
constraints may run eight lines and still be right. What is banned is four
lines making one point. Count the load-bearing claims, not the prose: if you
cannot name what each sentence adds, that sentence goes.

A comment that wants a paragraph for a *single* point is telling you the code
needs restructuring, or that the reasoning is aimed at a reviewer rather than
a caller — and that belongs in the commit message, read once, not in a doc
comment read forever.

**Delete the story, keep the finding.** "This failed in the full suite but
passed alone", "a body of five thousand characters came back truncated",
"this used to be stricter" — the incident is history. The constraint it
uncovered is category 1 and stays, in a line.

Then check it is not already written down somewhere:

- **A decision lives in the code once, in a line.** The PR body may argue it
  at length; the doc states it. Duplication is not the defect — the
  paragraph-length argument in the doc is. Never delete the only surviving
  record of a decision on the grounds that it "belongs" in a commit message:
  that commit is buried and nobody will find it.
- In the type's own doc. A member doc that re-says a long type doc looks
  informative beside its declaration and is redundant in context. Score the overlap; don't read the comment alone. The exception is a
  member doc the *type* doc promised — "each optional says which kinds
  populate it" — which discharges a contract rather than idling.
- In the symbol it describes. A pointer carrying no content of its own
  ("`nonisolated` for the reason X gives") is deleted. A pointer that cites a
  reason and then restates it keeps one copy, at the canonical site.

## Repeated house patterns are all-or-nothing

Some paragraphs recur verbatim across dozens of files. **Do not trim them in the files you happen
to be holding.** Piecemeal edits leave the codebase inconsistent and the next
reader unable to tell which absence is deliberate. Either sweep every
occurrence in one change, or leave them all. The same goes for a `- Parameter`
block: keep every entry or none, never a half-populated one.

## When `file_length` fires, measure the comments

Do not reword prose to fit, and do not split the file until you know why it is
long:

```
awk 'BEGIN{c=0;t=0} /^[[:space:]]*\/\//{c++} {t++} END{printf "%d%%\n", c*100/t}' <file>
```

Compare against the file's own baseline — `git show main:<path> | awk …` — and
if your change raised the ratio, cut what you added. Do not invent an absolute
threshold: some files already sit above 40%, and a flat number would condemn
them. The baseline is the inheritance, not the target.

`Scripts/comment-ratio.sh` does this for every changed file at once.

## Tests

A `@Test` display name is already a sentence. A comment above it earns its
place only by naming the regression it guards, in one line.
