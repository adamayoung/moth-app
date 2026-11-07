//  MothMigrationPlan.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import SwiftData

public typealias CurrentSchema = SchemaV3

public nonisolated enum MothMigrationPlan: SchemaMigrationPlan {

    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    /// Empty, because a staged migration can't identify a store holding only some of a version's models, and each
    /// store holds only its configuration's. SwiftData's automatic lightweight migration adds each version's changes.
    public static var stages: [MigrationStage] {
        []
    }

}
