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
