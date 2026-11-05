---
paths:
  - "TestPlans/*.xctestplan"
  - "Packages/*/Package.swift"
  - "Moth.xcodeproj/project.xcproj"
---

# Test plans and what ships in the app

`UnitTests.xctestplan` carries the app and package unit targets, and `UITests.xctestplan` carries `MothUITests`. A new test target must be added to the plan; the `Moth` scheme lists plans, not targets, so it needs no entry.

**A package in the project's `packages` array runs no tests.** With the packages there, which `xcrun xcodeproj pkg add-local` writes, `make test` passed having run none of their tests, with no warning. Keep them under the `Packages` folder entry, and read the `Ran N test(s).` count after adding one.

**A folder in the app target's membership ships inside `Moth.app`.** A `folder` entry in `project.xcproj` with `Moth` in its `target-membership` compiles what it can and copies every other file into the bundle, with no warning and no check. Keep `Packages/`, `TestPlans/` and `Configs/` out of the app target's membership, and read the built bundle's `Contents/Resources` after changing it. See [Module Boundaries](../../docs/architecture.md#module-boundaries).

**A build configuration's file must be a file reference.** A `configurations` entry in `project.xcproj` is `{ "name", "file" }`, and `file` must resolve to an entry under `files`. A `folder` entry does not satisfy it; a `group` with explicit children and no `target-membership` does.

Commands and filter syntax live in [Testing](../../docs/testing.md) and [UI Testing](../../docs/ui-testing.md).
