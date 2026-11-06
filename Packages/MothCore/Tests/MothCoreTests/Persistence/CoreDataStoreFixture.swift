//  CoreDataStoreFixture.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import CoreData
import Foundation
@testable import MothCore
import SwiftData
import Testing

/// Builds a store through Core Data, as `CloudKitSchemaInitialiser` does, so a test can change the model first.
enum CoreDataStoreFixture {

    static func makeStore(
        at url: URL,
        models: [any PersistentModel.Type],
        change: (NSManagedObjectModel) throws -> Void = { _ in }
    ) throws {
        let container = try load(at: url, models: models, change: change)
        if let store = container.persistentStoreCoordinator.persistentStores.first {
            try container.persistentStoreCoordinator.remove(store)
        }
    }

    /// Copies the files while the container is open, which is what a crash leaves behind: writes still in the `-wal`.
    static func makeStoreWithPendingLog(
        at url: URL,
        models: [any PersistentModel.Type],
        change: (NSManagedObjectModel) throws -> Void
    ) throws {
        let liveDirectory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: liveDirectory) }
        let liveURL = liveDirectory.appending(path: url.lastPathComponent)
        let container = try load(at: liveURL, models: models, change: change)
        let entityName = try #require(container.managedObjectModel.entities.first?.name)
        _ = NSEntityDescription.insertNewObject(forEntityName: entityName, into: container.viewContext)
        try container.viewContext.save()

        let target = url.deletingLastPathComponent()
        for file in try FileManager.default.contentsOfDirectory(at: liveDirectory, includingPropertiesForKeys: nil) {
            try FileManager.default.copyItem(at: file, to: target.appending(path: file.lastPathComponent))
        }
        if let store = container.persistentStoreCoordinator.persistentStores.first {
            try container.persistentStoreCoordinator.remove(store)
        }
    }

    static func addColumn(to model: NSManagedObjectModel) throws {
        let entity = try #require(model.entities.first)
        let attribute = NSAttributeDescription()
        attribute.name = "addedInNewerVersion"
        attribute.type = .string
        attribute.isOptional = true
        entity.properties.append(attribute)
    }

    static func addEntity(to model: NSManagedObjectModel) {
        let entity = NSEntityDescription()
        entity.name = "AddedInNewerVersion"
        model.entities.append(entity)
    }

    private static func load(
        at url: URL,
        models: [any PersistentModel.Type],
        change: (NSManagedObjectModel) throws -> Void
    ) throws -> NSPersistentContainer {
        let generated = try #require(NSManagedObjectModel.makeManagedObjectModel(for: models))
        let model = try #require(generated.copy() as? NSManagedObjectModel)
        try change(model)

        let description = NSPersistentStoreDescription(url: url)
        description.shouldAddStoreAsynchronously = false
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        let container = NSPersistentContainer(name: url.lastPathComponent, managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loadError: any Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }

}

enum StoreFiles {

    static func removeStore(named name: String, in directory: URL) throws {
        for suffix in ["", "-wal", "-shm"] {
            let file = directory.appending(path: name + suffix)
            if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
                try FileManager.default.removeItem(at: file)
            }
        }
    }

    static func contents(of directory: URL) throws -> [String: Data] {
        var contents: [String: Data] = [:]
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
        while let url = enumerator?.nextObject() as? URL {
            if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                contents[url.lastPathComponent] = try Data(contentsOf: url)
            }
        }
        return contents
    }

}
