---
paths:
  - "Packages/MothCore/Sources/MothCore/DataModels/**"
---

# A schema version on `main` is frozen

Before adding, removing or changing any stored property or relationship on a `@Model`, check whether the newest `SchemaVn` is on `main` (`git show origin/main:Packages/MothCore/Sources/MothCore/DataModels/Schema/MothMigrationPlan.swift`). If it is, cut the next version rather than editing it in place, even if nothing has shipped: any build of `main` may have written a store with it, and a store matching no planned version stops `DataModel` at launch. Only a version that exists solely on an unmerged branch may still change.

**CloudKit is stricter.** Once a schema is promoted to production it is additive only: a synced model type cannot be deleted and an existing attribute cannot be changed. A rename or a type change to a synced model is a new attribute plus a migration of the data, and the old attribute stays. See [Schema Versioning](../../docs/architecture.md#schema-versioning).

**Nest each `@Model` in the `SchemaVn` enum's body, not an `extension`.** SwiftFormat hoists `public` onto a `public`-only extension, and `@Model` reads the modifiers on the class, so it generates internal members. The build then fails inside macro-generated code, with "must be declared public because it matches a requirement in public protocol 'PersistentModel'". Keep `nonisolated` on the class too, so `@StoreActor` code can use it.
