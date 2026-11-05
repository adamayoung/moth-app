//  SchemaV1.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

/// Frozen once on `main`. `SchemaV1Tests` pins the shape and `StoredJSONTests` the JSON in the `Data` attributes.
///
/// Models are `public` for `@Query`, and only this module can set a property, so that every write goes through
/// ``StoreWriter``. They nest here, not in a `public`-only `extension`, because `@Model` reads the class's modifiers.
public nonisolated enum SchemaV1: VersionedSchema {

    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        syncedModels + localModels
    }

    static var syncedModels: [any PersistentModel.Type] {
        [
            WorkspaceModel.self,
            CollectionModel.self,
            FolderModel.self,
            RequestModel.self,
            EnvironmentModel.self,
            VariableModel.self
        ]
    }

    static var localModels: [any PersistentModel.Type] {
        [HistoryEntryModel.self]
    }

    @Model
    public final nonisolated class WorkspaceModel {

        public internal(set) var id = UUID()
        public internal(set) var activeEnvironmentID: UUID?

        /// Nullify, not cascade: a merge's delete reaches other Macs, where a cascade would take a child that has not
        /// synced yet. A nullified child is an orphan, which ``StoreWriter`` adopts.
        @Relationship(deleteRule: .nullify, inverse: \CollectionModel.workspace)
        public internal(set) var collections: [CollectionModel]? = []

        @Relationship(deleteRule: .nullify, inverse: \EnvironmentModel.workspace)
        public internal(set) var environments: [EnvironmentModel]? = []

        @Relationship(deleteRule: .nullify, inverse: \VariableModel.workspace)
        public internal(set) var globals: [VariableModel]? = []

        init() {}

    }

    @Model
    public final nonisolated class CollectionModel {

        public internal(set) var id = UUID()
        public internal(set) var name = ""
        public internal(set) var sortOrder = 0
        public internal(set) var authData: Data?
        public internal(set) var workspace: WorkspaceModel?

        @Relationship(deleteRule: .cascade, inverse: \FolderModel.collection)
        public internal(set) var folders: [FolderModel]? = []

        @Relationship(deleteRule: .cascade, inverse: \RequestModel.collection)
        public internal(set) var requests: [RequestModel]? = []

        @Relationship(deleteRule: .cascade, inverse: \VariableModel.collection)
        public internal(set) var variables: [VariableModel]? = []

        init() {}

    }

    @Model
    public final nonisolated class FolderModel {

        public internal(set) var id = UUID()
        public internal(set) var name = ""
        public internal(set) var sortOrder = 0
        public internal(set) var authData: Data?
        public internal(set) var collection: CollectionModel?
        public internal(set) var parent: FolderModel?

        @Relationship(deleteRule: .cascade, inverse: \FolderModel.parent)
        public internal(set) var subfolders: [FolderModel]? = []

        @Relationship(deleteRule: .cascade, inverse: \RequestModel.folder)
        public internal(set) var requests: [RequestModel]? = []

        init() {}

    }

    @Model
    public final nonisolated class RequestModel {

        public internal(set) var id = UUID()
        public internal(set) var name = ""
        public internal(set) var methodRawValue = HTTPMethod.get.rawValue
        public internal(set) var urlTemplate = ""
        public internal(set) var sortOrder = 0
        public internal(set) var queryParametersData: Data?
        public internal(set) var pathParametersData: Data?
        public internal(set) var headersData: Data?
        public internal(set) var authData: Data?
        public internal(set) var settingsData: Data?
        public internal(set) var collection: CollectionModel?
        public internal(set) var folder: FolderModel?

        @Attribute(.externalStorage)
        public internal(set) var bodyData: Data?

        @Relationship(deleteRule: .cascade, inverse: \VariableModel.request)
        public internal(set) var variables: [VariableModel]? = []

        init() {}

    }

    @Model
    public final nonisolated class EnvironmentModel {

        public internal(set) var id = UUID()
        public internal(set) var name = ""
        public internal(set) var sortOrder = 0
        public internal(set) var workspace: WorkspaceModel?

        @Relationship(deleteRule: .cascade, inverse: \VariableModel.environment)
        public internal(set) var variables: [VariableModel]? = []

        init() {}

    }

    /// A row each, so two Macs changing different variables of one owner do not overwrite each other.
    @Model
    public final nonisolated class VariableModel {

        public internal(set) var id = UUID()
        public internal(set) var name = ""
        public internal(set) var initialValue = ""
        public internal(set) var currentValue = ""
        public internal(set) var secretIdentifier: String?
        public internal(set) var isEnabled = true
        public internal(set) var sortOrder = 0

        /// An orphaned global would otherwise look like a variable whose owner has not been imported yet.
        public internal(set) var isGlobal = false

        public internal(set) var workspace: WorkspaceModel?
        public internal(set) var collection: CollectionModel?
        public internal(set) var environment: EnvironmentModel?
        public internal(set) var request: RequestModel?

        init() {}

    }

    /// `requestID` is a plain attribute because a relationship cannot cross from the local store to the synced one.
    @Model
    public final nonisolated class HistoryEntryModel {

        public internal(set) var id = UUID()
        public internal(set) var requestID = UUID()
        public internal(set) var requestData: Data?
        public internal(set) var sentAt = Date.distantPast
        public internal(set) var durationSeconds: Int64 = 0
        public internal(set) var durationAttoseconds: Int64 = 0
        public internal(set) var statusCode: Int?
        public internal(set) var responseHeadersData: Data?
        public internal(set) var failure: String?

        @Attribute(.externalStorage)
        public internal(set) var responseBody: Data?

        init() {}

    }

}

public typealias WorkspaceModel = SchemaV1.WorkspaceModel
public typealias CollectionModel = SchemaV1.CollectionModel
public typealias FolderModel = SchemaV1.FolderModel
public typealias RequestModel = SchemaV1.RequestModel
public typealias EnvironmentModel = SchemaV1.EnvironmentModel
public typealias VariableModel = SchemaV1.VariableModel
public typealias HistoryEntryModel = SchemaV1.HistoryEntryModel
