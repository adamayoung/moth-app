//  DataModel.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

/// Owns the stores. `mainContext` is for reading, with autosave off; every write goes through ``writer``.
public final class DataModel {

    public let container: ModelContainer
    public let writer: StoreWriter

    public var mainContext: ModelContext {
        container.mainContext
    }

    public init(location: DataModelLocation, containerIdentifier: String?) throws {
        if case .directory(let directory) = location {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let configurations = StoreConfigurations(location: location, containerIdentifier: containerIdentifier)
        self.container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV1.self),
            migrationPlan: MothMigrationPlan.self,
            configurations: configurations.all
        )
        self.writer = StoreWriter(container: container)
        container.mainContext.autosaveEnabled = false
    }

    /// Writes the seed directly, not through ``writer``: it runs before any reader exists, so a seeded launch has its
    /// data at the first frame, and the store is new and in memory, so there is nothing to reconcile with.
    public static func inMemory(seed: Workspace? = nil) throws -> DataModel {
        let dataModel = try DataModel(location: .inMemory, containerIdentifier: nil)
        if let seed {
            let context = ModelContext(dataModel.container)
            try context.insert(WorkspaceModel(seed))
            try context.save()
        }
        return dataModel
    }

}
