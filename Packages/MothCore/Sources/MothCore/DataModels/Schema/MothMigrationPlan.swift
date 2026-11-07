//  MothMigrationPlan.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import SwiftData

public nonisolated enum MothMigrationPlan: SchemaMigrationPlan {

    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    public static var stages: [MigrationStage] {
        []
    }

}
