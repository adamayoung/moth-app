//  CloudKitSchemaInitialiser.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

#if DEBUG
    import CoreData
    import Foundation
    import SwiftData

    /// SwiftData has no API for this, so it follows Apple's recipe in "Syncing model data across a person's devices".
    public nonisolated enum CloudKitSchemaInitialiser {

        public enum Failure: Error {
            case noManagedObjectModel
            case storeDidNotLoad(any Error)
        }

        /// Runs in an autorelease pool, and unloads the store, so that SwiftData and Core Data do not both sync it.
        public static func initialise(containerIdentifier: String, directory: URL) throws {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let configurations = StoreConfigurations(
                location: .directory(directory),
                containerIdentifier: containerIdentifier
            )
            try StoreSchemaCheck(knownSchemas: MothMigrationPlan.schemas)
                .verify(storesAt: configurations.onDiskStoreURLs)
            try autoreleasepool {
                guard let model = NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.syncedModels) else {
                    throw Failure.noManagedObjectModel
                }

                let description = NSPersistentStoreDescription(url: configurations.synced.url)
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: containerIdentifier
                )
                description.shouldAddStoreAsynchronously = false

                let container = NSPersistentCloudKitContainer(name: "Synced", managedObjectModel: model)
                container.persistentStoreDescriptions = [description]
                var loadError: any Error?
                container.loadPersistentStores { _, error in
                    loadError = error
                }
                if let loadError {
                    throw Failure.storeDidNotLoad(loadError)
                }

                try container.initializeCloudKitSchema()
                if let store = container.persistentStoreCoordinator.persistentStores.first {
                    try container.persistentStoreCoordinator.remove(store)
                }
            }
        }

    }
#endif
