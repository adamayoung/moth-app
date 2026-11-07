//  StoreConfigurations.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

public nonisolated enum DataModelLocation: Sendable, Equatable {

    case inMemory
    case directory(URL)

}

/// Each configuration names its own schema, so a model belongs to one store.
nonisolated struct StoreConfigurations {

    let synced: ModelConfiguration
    let local: ModelConfiguration

    var all: [ModelConfiguration] {
        [synced, local]
    }

    func verifyStoresAreKnown() throws {
        try StoreSchemaCheck(knownSchemas: MothMigrationPlan.schemas)
            .verify(storesAt: all.filter { !$0.isStoredInMemoryOnly }.map(\.url))
    }

    init(location: DataModelLocation, containerIdentifier: String?) {
        self.synced = Self.configuration(
            named: "Synced",
            models: CurrentSchema.syncedModels,
            location: location,
            cloudKitDatabase: containerIdentifier.map { .private($0) } ?? .none
        )
        self.local = Self.configuration(
            named: "Local",
            models: CurrentSchema.localModels,
            location: location,
            cloudKitDatabase: .none
        )
    }

    /// `cloudKitDatabase` is always explicit: its default, `.automatic`, uses CloudKit when the app has the
    /// entitlement.
    private static func configuration(
        named name: String,
        models: [any PersistentModel.Type],
        location: DataModelLocation,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase
    ) -> ModelConfiguration {
        let schema = Schema(models, version: CurrentSchema.versionIdentifier)
        return switch location {
        case .inMemory:
            ModelConfiguration(name, schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: cloudKitDatabase)
        case .directory(let directory):
            ModelConfiguration(
                name,
                schema: schema,
                url: directory.appending(path: "\(name).store"),
                cloudKitDatabase: cloudKitDatabase
            )
        }
    }

}
