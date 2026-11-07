//  MothMigrationPlan.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import SwiftData

public typealias CurrentSchema = SchemaV2

public nonisolated enum MothMigrationPlan: SchemaMigrationPlan {

    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    /// Empty, because a staged migration can't identify a store holding only some of a version's models, and each
    /// store holds only its configuration's. SwiftData's automatic lightweight migration adds V2's attributes.
    public static var stages: [MigrationStage] {
        []
    }

}
