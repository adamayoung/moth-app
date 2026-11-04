---
paths:
  - "Moth/Platform/**/*.swift"
---

# Objective-C callbacks trap under the `MainActor` default

The app target defaults to `MainActor`, so **a closure literal passed to an Objective-C API is inferred `@MainActor`**. When the framework calls it on its own queue, the runtime traps in the block thunk before the body runs: no compiler warning, no `Task { @MainActor in … }` inside it can help, and a Swift test double cannot reproduce it.

Write `@Sendable` on every completion handler handed to a framework, and make a seam's handler parameter `@escaping @Sendable`, so an isolated handler fails to compile. Delegate methods take `nonisolated` instead.

See [Concurrency](../../docs/architecture.md#concurrency).
