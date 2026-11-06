//  StoreSchemaCheck.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import CoreData
import Foundation
import SwiftData

public nonisolated struct UnknownStoreSchemaError: Error, Equatable {

    public let storeName: String

}

/// While a migration plan has no stages, SwiftData opens a store from an unknown schema with no error and drops the
/// columns it does not know, so this has to run before any store opens.
nonisolated struct StoreSchemaCheck {

    private struct NoManagedObjectModel: Error {}

    let knownSchemas: [any VersionedSchema.Type]

    func verify(storesAt urls: [URL]) throws {
        let storeURLs = try urls.filter(Self.holdsData)
        guard !storeURLs.isEmpty else {
            return
        }

        let knownHashes = try knownSchemas.map { schema in
            guard let model = NSManagedObjectModel.makeManagedObjectModel(for: schema.models) else {
                throw NoManagedObjectModel()
            }
            return model.entityVersionHashesByName
        }
        for url in storeURLs {
            let storeHashes = try Self.entityVersionHashes(ofStoreAt: url)
            let isKnown = knownHashes.contains { Self.holdsSameEntities($0, as: storeHashes) }
            guard !storeHashes.isEmpty, isKnown else {
                throw UnknownStoreSchemaError(storeName: url.lastPathComponent)
            }
        }
    }

    /// An empty file stays SwiftData's decision, because it starts a new store over one.
    private static func holdsData(_ url: URL) throws -> Bool {
        guard fileExists(url) else {
            return false
        }
        return try url.resourceValues(forKeys: [.fileSizeKey]).fileSize != 0
    }

    /// A subset, not equality: SwiftData lists a schema's every entity in each store's metadata, but a store made by
    /// `CloudKitSchemaInitialiser` lists only the synced models.
    private static func holdsSameEntities(_ known: [String: Data], as store: [String: Data]) -> Bool {
        store.allSatisfy { known[$0.key] == $0.value }
    }

    /// Reads a copy, because a metadata read changes the `-shm` file of a store with writes in its `-wal`. Any failure
    /// stops the launch: a store this cannot read might still open, and lose its newer columns.
    private static func entityVersionHashes(ofStoreAt url: URL) throws -> [String: Data] {
        let copyDirectory = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: copyDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: copyDirectory) }

        for suffix in ["", "-wal", "-shm"] {
            let file = url.deletingLastPathComponent().appending(path: url.lastPathComponent + suffix)
            if fileExists(file) {
                try FileManager.default.copyItem(at: file, to: copyDirectory.appending(path: file.lastPathComponent))
            }
        }
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            type: .sqlite,
            at: copyDirectory.appending(path: url.lastPathComponent)
        )
        return metadata[NSStoreModelVersionHashesKey] as? [String: Data] ?? [:]
    }

    private static func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

}
