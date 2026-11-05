//  SwiftDataNewerStoreCharacterisationTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

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

private nonisolated enum PlannedFixtureV1: VersionedSchema {

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

private nonisolated enum PlannedFixtureV2: VersionedSchema {

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

private nonisolated enum PlannedFixtureV3: VersionedSchema {

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

    @Test("Characterises SwiftData: a store from a newer schema opens with no error and loses the newer column")
    func characterisesOpeningANewerStore() throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appending(path: "Local.store")
        try Self.writeNewerStore(in: directory)
        #expect(try Self.values(of: Self.columnsQuery, at: store).contains(Self.newerColumn))

        _ = try DataModel(location: .directory(directory), containerIdentifier: nil)

        #expect(try Self.values(of: Self.rowCountQuery, at: store) == ["1"])
        #expect(try !Self.values(of: Self.columnsQuery, at: store).contains(Self.newerColumn))
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
