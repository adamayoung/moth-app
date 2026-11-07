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
        let schema = Schema(versionedSchema: SchemaV2.self)
        let cookie = try #require(schema.entitiesByName["CookieModel"])

        #expect(Set(cookie.attributesByName.keys) == [
            "id", "workspaceID", "name", "domain", "isHostOnly", "path", "expiresAt", "isSecure", "isHTTPOnly",
            "createdAt", "valueIdentifier"
        ])
        #expect(cookie.relationships.isEmpty)
    }

    @Test("SchemaV2 keeps every SchemaV1 model as it was, and adds cookies")
    func schemaV2AddsCookies() {
        let earlier = Set(SchemaV1.models.map { "\($0)" })
        let later = Set(SchemaV2.models.map { "\($0)" })

        #expect(later.subtracting(earlier) == ["CookieModel"])
        #expect(earlier.isSubset(of: later))
    }

    @Test("The migration plan holds SchemaV1 then SchemaV2, with no stages")
    func migrationPlan() {
        #expect(MothMigrationPlan.schemas.map { "\($0)" } == ["SchemaV1", "SchemaV2"])
        #expect(MothMigrationPlan.stages.isEmpty)
    }

    @Test("A SchemaV1 store on disk opens as SchemaV2, keeps its rows and takes cookies")
    func schemaV1StoreOpens() async throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let entry = DomainFixtures.historyEntry()
        try Self.writeSchemaV1Stores(holding: entry, in: directory)

        let dataModel = try DataModel(location: .directory(directory), containerIdentifier: nil)
        try await dataModel.writer.saveCookies([CookieRecord(cookie: CookieFixtures.cookie())], in: UUID())

        let entries = try dataModel.mainContext.fetch(FetchDescriptor<HistoryEntryModel>())
        #expect(try entries.map { try $0.asDomain() } == [entry])
        #expect(try dataModel.mainContext.fetchCount(FetchDescriptor<CookieModel>()) == 1)
    }

    private static func writeSchemaV1Stores(holding entry: HistoryEntry, in directory: URL) throws {
        let synced = Schema(SchemaV1.syncedModels, version: SchemaV1.versionIdentifier)
        let local = Schema(SchemaV1.localModels, version: SchemaV1.versionIdentifier)
        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV1.self),
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
