//  SchemaV2.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

/// SchemaV1's models unchanged, and cookies in the local store. SwiftData's automatic lightweight migration opens a
/// SchemaV1 store; a stage would refuse it, because each store holds only its configuration's models.
public nonisolated enum SchemaV2: VersionedSchema {

    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        syncedModels + localModels
    }

    static var syncedModels: [any PersistentModel.Type] {
        SchemaV1.syncedModels
    }

    static var localModels: [any PersistentModel.Type] {
        SchemaV1.localModels + [CookieModel.self]
    }

    /// The value is a device-only Keychain item named by `valueIdentifier`, so the store holds no credential.
    /// `workspaceID` is a plain attribute because a relationship cannot cross from the local store to the synced one.
    @Model
    public final nonisolated class CookieModel {

        public internal(set) var id = UUID()
        public internal(set) var workspaceID = UUID()
        public internal(set) var name = ""
        public internal(set) var domain = ""
        public internal(set) var isHostOnly = true
        public internal(set) var path = "/"
        public internal(set) var expiresAt: Date?
        public internal(set) var isSecure = false
        public internal(set) var isHTTPOnly = false
        public internal(set) var createdAt = Date.distantPast
        public internal(set) var valueIdentifier = ""

        init() {}

    }

}

public typealias CookieModel = SchemaV2.CookieModel

/// The newest version, which the stores open as.
typealias CurrentSchema = SchemaV2
