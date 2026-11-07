//  SchemaV2.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

/// Frozen once on `main`. `SchemaV2Tests` pins the shape. Changes only the local store, so CloudKit sees no change.
public nonisolated enum SchemaV2: VersionedSchema {

    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        syncedModels + localModels
    }

    static var syncedModels: [any PersistentModel.Type] {
        SchemaV1.syncedModels
    }

    static var localModels: [any PersistentModel.Type] {
        [HistoryEntryModel.self]
    }

    /// `requestID` is a plain attribute because a relationship cannot cross from the local store to the synced one.
    /// `method` and `url` repeat what `requestData` holds, so a sidebar row decodes no JSON.
    @Model
    public final nonisolated class HistoryEntryModel {

        public internal(set) var id = UUID()
        public internal(set) var requestID = UUID()
        public internal(set) var requestData: Data?
        public internal(set) var method = ""
        public internal(set) var url = ""
        public internal(set) var sentAt = Date.distantPast
        public internal(set) var durationSeconds: Int64 = 0
        public internal(set) var durationAttoseconds: Int64 = 0
        public internal(set) var statusCode: Int?
        public internal(set) var reasonPhrase: String?
        public internal(set) var responseHeadersData: Data?
        public internal(set) var responseSize = 0
        public internal(set) var timingData: Data?
        public internal(set) var failure: String?
        public internal(set) var failureKind: String?

        @Attribute(.externalStorage)
        public internal(set) var responseBody: Data?

        init() {}

    }

}

public typealias HistoryEntryModel = SchemaV2.HistoryEntryModel
