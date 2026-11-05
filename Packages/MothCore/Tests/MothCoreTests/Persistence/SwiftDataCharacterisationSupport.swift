//  SwiftDataCharacterisationSupport.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

enum StoreLocation: CaseIterable {
    case inMemory
    case onDisk
}

enum CharacterisationStore {

    /// `.automatic`, the default, uses CloudKit when the test host has the entitlement.
    static func inMemoryConfiguration(named name: String? = nil, schema: Schema) -> ModelConfiguration {
        ModelConfiguration(name, schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    }

    static func onDiskConfiguration(named name: String, schema: Schema, in directory: URL) -> ModelConfiguration {
        ModelConfiguration(
            name,
            schema: schema,
            url: directory.appending(path: "\(name).store"),
            cloudKitDatabase: .none
        )
    }

    static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "SwiftDataCharacterisationTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

}
