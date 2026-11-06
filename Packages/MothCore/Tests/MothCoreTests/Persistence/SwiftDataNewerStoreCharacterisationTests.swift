//  SwiftDataNewerStoreCharacterisationTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import CoreData
import Foundation
@testable import MothCore
import SQLite3
import SwiftData
import Testing

private enum NewerLocalStoreFixture {

    @Model
    final class HistoryEntryModel {

        var id = UUID()
        var requestID = UUID()
        var requestData: Data?
        var sentAt = Date.distantPast
        var durationSeconds: Int64 = 0
        var durationAttoseconds: Int64 = 0
        var statusCode: Int?
        var responseHeadersData: Data?
        var failure: String?

        @Attribute(.externalStorage)
        var responseBody: Data?

        var addedInNewerVersion = "newer data"

        init() {}

    }

}

nonisolated enum PlannedFixtureV1: VersionedSchema {

    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [PlannedRow.self]
    }

    @Model
    final nonisolated class PlannedRow {

        var name = "kept"

        init() {}

    }

}

nonisolated enum PlannedFixtureV2: VersionedSchema {

    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [PlannedRow.self]
    }

    @Model
    final nonisolated class PlannedRow {

        var name = "kept"
        var addedInV2 = ""

        init() {}

    }

}

nonisolated enum PlannedFixtureV3: VersionedSchema {

    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [PlannedRow.self]
    }

    @Model
    final nonisolated class PlannedRow {

        var name = "kept"
        var addedInV2 = ""
        var addedInV3 = ""

        init() {}

    }

}

private nonisolated enum PlannedFixtureMigrationPlan: SchemaMigrationPlan {

    static var schemas: [any VersionedSchema.Type] {
        [PlannedFixtureV1.self, PlannedFixtureV2.self]
    }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: PlannedFixtureV1.self, toVersion: PlannedFixtureV2.self)]
    }

}

struct SwiftDataNewerStoreCharacterisationTests {

    @Test("Characterises SwiftData: with no stages in the plan, a newer store opens and loses the newer column")
    func characterisesOpeningANewerStore() throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appending(path: "Local.store")
        try Self.writeNewerStore(in: directory)
        #expect(try Self.values(of: Self.columnsQuery, at: store).contains(Self.newerColumn))

        let configurations = StoreConfigurations(location: .directory(directory), containerIdentifier: nil)
        _ = try ModelContainer(
            for: Schema(versionedSchema: SchemaV1.self),
            migrationPlan: MothMigrationPlan.self,
            configurations: configurations.all
        )

        #expect(try Self.values(of: Self.rowCountQuery, at: store) == ["1"])
        #expect(try !Self.values(of: Self.columnsQuery, at: store).contains(Self.newerColumn))
    }

    @Test("DataModel refuses the store SwiftData would have damaged, which keeps its row and its column")
    func dataModelRefusesANewerStore() throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appending(path: "Local.store")
        try Self.writeNewerStore(in: directory)

        #expect(throws: UnknownStoreSchemaError(storeName: "Local.store")) {
            try DataModel(location: .directory(directory), containerIdentifier: nil)
        }

        #expect(try Self.values(of: Self.rowCountQuery, at: store) == ["1"])
        #expect(try Self.values(of: Self.columnsQuery, at: store).contains(Self.newerColumn))
    }

    @Test("Characterises Core Data: SchemaV1's entity hashes hold, or StoreSchemaCheck refuses every existing store")
    func characterisesSchemaV1EntityHashes() throws {
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.models))

        let hashes = model.entityVersionHashesByName.mapValues { $0.base64EncodedString() }

        #expect(hashes == Self.schemaV1EntityHashes)
    }

    @Test("Characterises SwiftData: with a migration stage in the plan, a store from a newer schema does not open")
    func characterisesOpeningANewerStoreWithAStage() throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let newest = Schema(versionedSchema: PlannedFixtureV3.self)
        let newestConfiguration = CharacterisationStore.onDiskConfiguration(named: "Row", schema: newest, in: directory)
        do {
            let container = try ModelContainer(for: newest, configurations: newestConfiguration)
            let context = ModelContext(container)
            context.insert(PlannedFixtureV3.PlannedRow())
            try context.save()
        }

        let older = Schema(versionedSchema: PlannedFixtureV2.self)
        let olderConfiguration = CharacterisationStore.onDiskConfiguration(named: "Row", schema: older, in: directory)

        #expect(throws: (any Error).self) {
            try ModelContainer(
                for: older,
                migrationPlan: PlannedFixtureMigrationPlan.self,
                configurations: olderConfiguration
            )
        }

        let store = directory.appending(path: "Row.store")
        #expect(try Self.values(of: "SELECT COUNT(*) FROM ZPLANNEDROW", at: store) == ["1"])
        #expect(try Self.values(of: "SELECT name FROM pragma_table_info('ZPLANNEDROW')", at: store)
            .contains("ZADDEDINV3"))
    }

    private static let schemaV1EntityHashes = [
        "CollectionModel": "0UCbueFqp5AjBe2Zvss2MzYdufmxScVCls1USPloZog=",
        "EnvironmentModel": "bEwXj35RNQw3GS0vEJkQCVUhzS9YbOsaFwHO4CztWk8=",
        "FolderModel": "NuXp8/YOwcg9bUo4T4h14juzE7p8/hZcavAYvyYntoc=",
        "HistoryEntryModel": "EgOwK7XyKkKnFzvXvlEQDPIfrmc862y3ZKKf31gY89k=",
        "RequestModel": "6KEPNCfhOrUgft6i+1Ui8UfrXc0ya40rnrzQUWIdUMA=",
        "VariableModel": "5heyuByXhjnR7/js10D3bA7u3mBXQbm6QIWyfAMtGZo=",
        "WorkspaceModel": "Q4zOCtY8A+VFp9W/FNpHP3JMah1I1HoXrU/WSebZOeo="
    ]

    private static let columnsQuery = "SELECT name FROM pragma_table_info('ZHISTORYENTRYMODEL')"
    private static let rowCountQuery = "SELECT COUNT(*) FROM ZHISTORYENTRYMODEL"
    private static let newerColumn = "ZADDEDINNEWERVERSION"

    private static func writeNewerStore(in directory: URL) throws {
        let schema = Schema([NewerLocalStoreFixture.HistoryEntryModel.self], version: Schema.Version(2, 0, 0))
        let configuration = CharacterisationStore.onDiskConfiguration(named: "Local", schema: schema, in: directory)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)
        context.insert(NewerLocalStoreFixture.HistoryEntryModel())
        try context.save()
    }

    private static func values(of query: String, at url: URL) throws -> [String] {
        var database: OpaquePointer?
        defer { sqlite3_close(database) }
        try #require(sqlite3_open(url.path(), &database) == SQLITE_OK)
        sqlite3_busy_timeout(database, 5000)
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        try #require(sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK)
        var values: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            values.append(String(cString: sqlite3_column_text(statement, 0)))
        }
        return values
    }

}
