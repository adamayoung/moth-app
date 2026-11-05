# Moth Documentation

These documents are the working guide for contributors and coding agents. Read
the relevant page before changing that area, then verify its claims against the
current code. Source code, test plans, and tool configuration are authoritative
when documentation has drifted.

## Guide Index

| Document | Read before |
| --- | --- |
| [Architecture](architecture.md) | Changing module boundaries, dependencies, build configuration, persistence, CloudKit, secrets, networking, launch modes, or concurrency |
| [Roadmap](roadmap.md) | Deciding what belongs in which phase |
| [Code Style](code-style.md) | Writing or reviewing Swift, SwiftUI, localization, or documentation |
| [Testing](testing.md) | Adding tests, choosing a test target, filtering a run, interpreting CI, or working in a worktree |
| [UI Testing](ui-testing.md) | Changing `MothUITests`, seed data, screen objects, accessibility identifiers, or UI test plans, or diagnosing a failed UI run |

## Repository at a Glance

- `Moth/` contains the app target: scenes, SwiftUI views, commands, composition,
  and platform integrations.
- `Packages/` contains `HTTPKit`, `MothCore`, `MothImport`, and `PostmanKit`.
- `MothTests/` contains app-level unit and integration tests.
- `MothUITests/` contains XCTest UI suites and screen objects.
- `TestPlans/` defines the unit and UI plans.
- `Configs/`, `.swiftformat`, `.swiftlint.yml`, and `Makefile` define build and
  quality tooling.

## Instruction Ownership

- `CLAUDE.md` owns skill routing, the choice between the Xcode MCP and Make,
  and agent delegation.
- [Code Style](code-style.md) owns formatting and lint commands.
- [Testing](testing.md) owns build, unit, and package test commands and result
  interpretation.
- [UI Testing](ui-testing.md) owns UI plans, filters, and UI-test commands.
- Project skills own task-specific sequences such as Canon TDD and issue
  implementation; they should link to these guides instead of redefining
  command syntax.
- `.claude/rules/` holds short notes that load automatically when a matching
  file is opened. They exist to flag traps that fail silently, and they link
  back to these guides rather than restating them. A session that never opens
  a matching file never sees them, so no guidance may live there alone.

Never commit credentials, tokens, `.env` files, or generated result bundles.
