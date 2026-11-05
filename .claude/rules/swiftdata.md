---
paths:
  - "Packages/MothCore/Sources/MothCore/**/*.swift"
  - "Packages/MothCore/Tests/**/*.swift"
  - "Packages/MothImport/Sources/**/*.swift"
  - "Moth/Models/**/*.swift"
  - "MothTests/**/*.swift"
---

# SwiftData traps that fail without an error

**A `#Predicate` that reads a related object's property is evaluated against the store, not the context's unsaved changes.** A fetch that must see a change made earlier in the same unsaved context (`$0.collection?.name` after a rename) matches the old value and returns the wrong rows silently. Walk the relationship instead. Read-only queries over saved data are fine.

**Bind a `DataModel` to a local before taking its `mainContext`.** `DataModel(url:).mainContext` in one expression compiles, then traps inside SwiftData on the first fetch because nothing retains the container. In a test that kills the `xctest` process, and every test in the bundle reports a crash with no assertion message; the newest `xctest*.ips` crash report names the real test.

**A save writes back the whole row, as this context last read it.** SwiftData has no merge policy: a context that fetched a row before another context saved it reverts that save, even for properties it never set, and an equal-value assignment or a relationship edit counts as a change. Write only from `@StoreActor` code or through `StoreWriter.write`, fetching every row it changes by id with a `FetchDescriptor`, never `model(for:)`, then changing and saving them, all in one synchronous step with no `await` inside it, and calling `rollback()` if the write fails, because a fetch does not refresh a row with pending changes; never write a row a view handed in, never save the main context, and compare before assigning. See [Writing to the Store](../../docs/architecture.md#writing-to-the-store).

**A synced model must stay CloudKit-compatible.** No `@Attribute(.unique)`, no non-optional relationship, no `.deny` delete rule, a default on every stored property, and a `sortOrder` field for ordering. Secrets never go in a model: it holds an identifier, and the Keychain holds the value. A relationship does not cross from the synced store to the local one: related models silently share one store, which varies per container and could be the synced one, and relating rows already in different stores traps. See [CloudKit Model Rules](../../docs/architecture.md#cloudkit-model-rules).
