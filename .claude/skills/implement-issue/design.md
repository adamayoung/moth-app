# Design the change

A `/create-issue` spec says **what** to build: the behaviour, the user's
decisions, the acceptance criteria. It names no files. Working out **how**
is this run's job, against the code as it is now. Read only until the design
is posted.

## Research

Read the docs `CLAUDE.md` names for the area (`docs/architecture.md` for
models, sync and navigation; `docs/testing.md` and
`docs/ui-testing.md` for what the harness can observe), then the code.
Establish, with file paths and symbol names you have opened:

1. **How the analogue works, end to end**, if the issue names one: where its
   UI element lives, what state it reads, who publishes that state, where it
   is registered, the sheet or view it opens, its string keys and its tests.
   The new feature follows the same path unless the issue says otherwise.
2. **What already exists on the new feature's side**: views, model methods,
   string keys, preview services, fixtures, and
   what is missing that the analogue has (a title, accessibility
   identifiers, an opener on `MothTestCase`).
3. **What the test harness can observe**: seed data, which seeded dependency
   answers under `-UITesting` and what it returns, the screen objects to model
   on, and whether each
   acceptance criterion's outcome is visible at all. If one is not, the
   design adds what makes it visible.
4. **Docs the change will make wrong**: any section of `docs/` that
   describes the code being changed. Where a doc quotes a count the change
   moves, re-count rather than add to it.

## Decisions the issue left open

The issue's Decisions section holds the user's choices; follow them. A
question the issue does not answer and a user would notice (a disabled
state, wording) is a product decision you are taking on their
behalf: follow the analogue, or the nearest existing behaviour, and record
it for the PR body's "Decisions taken" section with the one-line
alternative. A question about the code's structure is yours to settle
without recording.

## The design comment

Post one comment on the issue (`gh issue comment <N> --body-file <file>`)
before writing any code, holding:

- **Design**: per file, what to add or change, with symbol names and
  accessibility identifiers. Strings as a Key | Value | Comment table.
- **Decisions taken**: as above, or "none".
- **Test list**: from `canon-tdd`: the unit tests and the UI test classes.
- **Docs to update**: document and section.

Keep it short enough to read in two minutes; it is a record of intent, not
a second spec. Where the code later forces a different choice, say so in
the PR body rather than editing the comment.
