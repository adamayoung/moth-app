# Code Style

## Source of Truth

`.swiftformat` and `.swiftlint.yml` define style. Do not infer a competing rule
from nearby code or spend review time on something the tools settle. The main
defaults are four-space indentation, a 120-column limit, sorted imports, no
force unwraps, and configured attribute placement.

`CLAUDE.md` determines which workflow or delegated agent performs these
operations. The commands below are the canonical direct-terminal and fallback
sequence for every edited Swift file:

```bash
swiftlint --fix path/to/File.swift
swiftformat path/to/File.swift
swiftlint --strict path/to/File.swift
swiftformat --lint path/to/File.swift
```

Use `make lint` before handoff. Use `make format` only when a deliberate
repository-wide formatting pass is in scope; it rewrites all Swift sources.

## Files and Naming

- Use PascalCase for types and camelCase for functions, properties, and local
  values.
- Name files after their primary type or focused extension.
- Keep one clear responsibility per file. Group files by feature and layer.
- A SwiftData model's `FetchDescriptor` builders live in
  `<Model>+Descriptors.swift`, never in the model's own file.
- New Swift source files use the standard copyright header. SwiftFormat chooses
  the module name from the nearest `.swiftformat`, so give a new module a local
  configuration. Package manifests are exempt.

Prefer names that describe domain behaviour over implementation mechanics.
Protocols use capability names such as `HTTPTransport`; live implementations
generally use the `Default` or `URLSession` prefix, while test doubles state
their behaviour (`Recording…`, `Stub…`, `NoOp…`).

## Swift and SwiftUI Practices

- Prefer value types. Use reference types when identity, observation, or actor
  isolation requires them.
- Keep views declarative and small. Move reusable presentation into the design
  system and domain behaviour into models or services.
- Read persisted collections with `@Query`; route mutations and asynchronous
  commands through `AppModel` or the owning service.
- Inject dependencies through initializers or established environment values.
  Do not add service singletons.
- Respect Swift 6 isolation. Do not add `Task.detached`, unchecked `Sendable`,
  or broad `nonisolated` annotations merely to silence a compiler diagnostic.
- Use early-exit `guard` statements, exhaustive switches, and `try #require` in
  tests instead of forced unwraps.
- SwiftUI does not adapt explicit `.transition(…)` or `.animation(…)` to Reduce
  Motion. Read `@Environment(\.accessibilityReduceMotion)` and check it at the
  modifier.
- Under `.windowResizability(.contentSize)` a main window opens at its content's
  minimum and ignores `.defaultSize`, so use `.contentMinSize`. AppKit restores
  a saved `NSWindow Frame <name>` over a scene's size, and the name changes with
  the scene's content modifiers.

Attribute placement is configured jointly by SwiftLint and SwiftFormat. Property
wrappers such as `@State` and `@Environment` stay on the declaration line;
type and function attributes, and attributes with arguments, generally sit on
the preceding line. Run both tools rather than aligning these by eye.

## User-Facing Content and Comments

Localize every user-visible string in the catalog owned by its target. App
strings live under `Moth/Resources`; package-local strings stay beside that
package's sources and use `bundle: .module`. Keep accessibility labels
meaningful without exposing test-only wording.

A build run by Xcode, including one through the Xcode MCP, writes the strings it
extracts back into `Localizable.xcstrings`; a `make` build does not. A new key
arrives with no `localizations` block. Check `git status` after such a build and
give each new key its `en-GB` value, as the `string-catalog` skill describes,
rather than reverting the catalog.

Copy is British English and follows these rules:

- Title Case for labels, buttons, menu commands, headings, tab names and status
  titles that are fragments. Articles, coordinating conjunctions and short
  prepositions stay lower case unless first or last.
- Sentence case for sentences. An alert title that is a complete sentence ends
  with punctuation; a fragment does not.
- The apostrophe ’ (U+2019), quotation marks “ ” (U+201C, U+201D) and the
  ellipsis … (U+2026), never their typewriter forms.
- Contractions ("can’t", "isn’t"), and the app is "Moth", never "we".

Comments should explain constraints, tradeoffs, or surprising platform
behaviour. Avoid narrating obvious code.
[.claude/rules/code-comments.md](../.claude/rules/code-comments.md) owns this
rule and states it in full.

`Scripts/comment-ratio.sh [base]` reports each changed Swift file whose comment
ratio rose by five points or more. It diffs `<base>...HEAD` of the checkout it
runs in, so run it inside the tree under review.
