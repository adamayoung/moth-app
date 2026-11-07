//  CookieSchemaTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

struct CookieSchemaTests {

    private let configurations = StoreConfigurations(location: .inMemory, containerIdentifier: nil)

    @Test("Cookies live in the local store only, so they never sync")
    func cookiesAreLocal() throws {
        let local = try #require(configurations.local.schema)
        let synced = try #require(configurations.synced.schema)

        #expect(local.entitiesByName["CookieModel"] != nil)
        #expect(synced.entitiesByName["CookieModel"] == nil)
    }

    @Test("A cookie row holds its metadata and a Keychain reference, never its value")
    func cookieRowHoldsNoValue() throws {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let cookie = try #require(schema.entitiesByName["CookieModel"])

        #expect(Set(cookie.attributesByName.keys) == [
            "id", "workspaceID", "name", "domain", "isHostOnly", "path", "expiresAt", "isSecure", "isHTTPOnly",
            "createdAt", "valueIdentifier"
        ])
        #expect(cookie.relationships.isEmpty)
    }

    @Test("SchemaV3 keeps every SchemaV2 model as it was, and adds cookies")
    func schemaV3AddsCookies() {
        let earlier = Set(SchemaV2.models.map { "\($0)" })
        let later = Set(SchemaV3.models.map { "\($0)" })

        #expect(later.subtracting(earlier) == ["CookieModel"])
        #expect(earlier.isSubset(of: later))
        #expect(SchemaV3.syncedModels.map { "\($0)" } == SchemaV2.syncedModels.map { "\($0)" })
    }

    @Test("The migration plan ends at SchemaV3, the version the stores open as, with no stages")
    func migrationPlan() {
        #expect(MothMigrationPlan.schemas.map { "\($0)" } == ["SchemaV1", "SchemaV2", "SchemaV3"])
        #expect(MothMigrationPlan.stages.isEmpty)
        #expect(CurrentSchema.self == SchemaV3.self)
    }

    @Test("A SchemaV2 store on disk opens as SchemaV3, keeps its rows and takes cookies")
    func schemaV2StoreOpens() async throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Self.writeSchemaV2Stores(holding: DomainFixtures.historyEntry(), in: directory)

        let dataModel = try DataModel(location: .directory(directory), containerIdentifier: nil)
        try await dataModel.writer.saveCookies([CookieRecord(cookie: CookieFixtures.cookie())], in: UUID())

        #expect(try dataModel.mainContext.fetchCount(FetchDescriptor<HistoryEntryModel>()) == 1)
        #expect(try dataModel.mainContext.fetchCount(FetchDescriptor<CookieModel>()) == 1)
    }

    private static func writeSchemaV2Stores(holding entry: HistoryEntry, in directory: URL) throws {
        let synced = Schema(SchemaV2.syncedModels, version: SchemaV2.versionIdentifier)
        let local = Schema(SchemaV2.localModels, version: SchemaV2.versionIdentifier)
        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV2.self),
            configurations: [
                CharacterisationStore.onDiskConfiguration(named: "Synced", schema: synced, in: directory),
                CharacterisationStore.onDiskConfiguration(named: "Local", schema: local, in: directory)
            ]
        )
        let context = ModelContext(container)
        try context.insert(HistoryEntryModel(entry))
        try context.save()
    }

}
