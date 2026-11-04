---
paths:
  - "Packages/HTTPKit/**/*.swift"
  - "Packages/PostmanKit/**/*.swift"
---

# This module is not MainActor by default

`HTTPKit` and `PostmanKit` share every package's upcoming features and warnings-as-errors, but are the only packages here without `.defaultIsolation(MainActor.self)`. In `MothCore`, `MothImport`, and the `Moth` app target (via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), a type with no annotation is main-actor isolated; the Xcode test targets set no default either. **In these two packages it is `nonisolated`**, and nothing in the file says so.

So a pattern lifted from `MothCore` compiles here with different semantics, and a diagnostic that looks like a missing annotation usually is not one. Do not add `@MainActor` to quiet it: these packages exist to run off the main actor, and pinning one drags network work onto it. Do not add `.defaultIsolation(MainActor.self)` to the manifest either — that changes every file in the package. Fix the actual crossing, keep wire models `Sendable` value types, and leave SwiftData and UI out of these packages entirely ([Architecture](../../docs/architecture.md#module-boundaries)).
