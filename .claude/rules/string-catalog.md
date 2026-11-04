---
paths:
  - "Moth/Resources/Localizable.xcstrings"
  - "Moth/Resources/Moth-InfoPlist.xcstrings"
---

# Editing the string catalog

**Invoke the `string-catalog` skill before changing this file.** It holds the procedure, both plural shapes with working JSON, and the failure modes that a green build does not catch.

The two that cost the most. **A string whose text contains a count is varied by plural in the catalog, one key — never a `count == 1 ? "FOO" : "FOOS"` pair chosen in Swift**, because a ternary caps you at two branches and Polish and Russian need `few` and `many` besides `one` and `other`. The single exception is a string that never displays its count, like a title shown beside a number the view draws itself: `xcstringstool` rejects a plural variation whose *value* does not reference the number — `error: Plural variation requires referencing the number in the string (OPEN_REQUESTS_%lld)` — and names separate top-level keys as the answer, so those keep their ternary and each key comments the name of its other half. And **Xcode's Vary by Plural prepopulates both variants with the existing plural text**, so the `one` case arrives carrying the plural's verb and article: "%lld request **are** waiting to send" is the bug that ships when only the noun gets fixed.

**A build run by Xcode, including the Xcode MCP, writes extracted strings back into `Localizable.xcstrings`; `make` does not.** New keys arrive with no `localizations` block. Give each its `en-GB` value rather than reverting the file: the string stays in the app either way, and the next Xcode build adds the key back. See [Code Style](../../docs/code-style.md#user-facing-content-and-comments).
