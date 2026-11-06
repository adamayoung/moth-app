//  StoreWriterRequestTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

struct StoreWriterRequestTests {

    private let edit = RequestEdit(
        method: .post,
        urlTemplate: "https://example.com/users/:id",
        queryParameters: [KeyValue(key: "limit", value: "10", isEnabled: false)],
        pathParameters: [KeyValue(key: "id", value: "42")],
        headers: [KeyValue(key: "Accept", value: "text/plain")],
        body: .urlEncoded([KeyValue(key: "name", value: "Ada")]),
        auth: .none
    )

    private func savedRequest(_ id: Request.ID, in dataModel: DataModel) throws -> Request {
        let rows = try TreeFixtures.savedRows(RequestModel.self, in: dataModel)
        return try #require(rows.first { $0.id == id }).asDomain()
    }

    @Test("Saving an edit writes the editor's fields")
    func writesEditedFields() async throws {
        let request = Request(name: "Request")
        let dataModel = try TreeFixtures.dataModel(
            holding: RequestCollection(name: "API", children: [TreeFixtures.item(0, request)])
        )

        try await dataModel.writer.updateRequest(request.id, with: edit, replacing: request.auth)

        #expect(try RequestEdit(savedRequest(request.id, in: dataModel)) == edit)
    }

    @Test("Saving an edit keeps a rename made since the draft was taken")
    func keepsRename() async throws {
        let request = Request(name: "Request")
        let dataModel = try TreeFixtures.dataModel(
            holding: RequestCollection(name: "API", children: [TreeFixtures.item(0, request)])
        )
        try await dataModel.writer.rename(.request(request.id), to: "Renamed")

        try await dataModel.writer.updateRequest(request.id, with: edit, replacing: request.auth)

        #expect(try savedRequest(request.id, in: dataModel).name == "Renamed")
    }

    @Test("Saving an edit keeps the settings and variables")
    func keepsOtherFields() async throws {
        let request = Request(
            name: "Request",
            settings: RequestSettings(timeout: .seconds(5)),
            variables: [Variable(name: "page", value: .plain(initial: "1", current: "2"))]
        )
        let dataModel = try TreeFixtures.dataModel(
            holding: RequestCollection(name: "API", children: [TreeFixtures.item(0, request)])
        )

        try await dataModel.writer.updateRequest(request.id, with: edit, replacing: request.auth)

        let saved = try savedRequest(request.id, in: dataModel)
        #expect(saved.settings == request.settings)
        #expect(saved.variables == request.variables)
    }

    @Test("Saving an edit updates every row with the identifier, because sync can duplicate one")
    func updatesDuplicates() async throws {
        let request = Request(name: "Request")
        let dataModel = try TreeFixtures.dataModel(
            holding: RequestCollection(name: "API", children: [TreeFixtures.item(0, request)])
        )
        let context = ModelContext(dataModel.container)
        try context.insert(RequestModel(request, sortOrder: 1))
        try context.save()

        try await dataModel.writer.updateRequest(request.id, with: edit, replacing: request.auth)

        let rows = try TreeFixtures.savedRows(RequestModel.self, in: dataModel)
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.urlTemplate == edit.urlTemplate })
    }

    @Test("Saving an edit refuses a row this build can't read, because it may hold fields the editor never showed")
    func refusesUnreadableRow() async throws {
        let request = Request(name: "Request")
        let dataModel = try TreeFixtures.dataModel(
            holding: RequestCollection(name: "API", children: [TreeFixtures.item(0, request)])
        )
        let unreadable = Data("not JSON".utf8)
        let context = ModelContext(dataModel.container)
        let row = try #require(context.fetch(RequestModel.withID(request.id)).first)
        row.queryParametersData = unreadable
        try context.save()

        await #expect(throws: (any Error).self) {
            try await dataModel.writer.updateRequest(request.id, with: edit, replacing: request.auth)
        }

        let saved = try #require(TreeFixtures.savedRows(RequestModel.self, in: dataModel).first)
        #expect(saved.queryParametersData == unreadable)
        #expect(saved.urlTemplate == request.urlTemplate)
    }

    @Test("Saving an edit to a request that has gone writes nothing")
    func requestHasGone() async throws {
        let dataModel = try TreeFixtures.dataModel(holding: RequestCollection(name: "API"))

        try await dataModel.writer.updateRequest(UUID(), with: edit, replacing: .inherit)

        #expect(try TreeFixtures.savedRows(RequestModel.self, in: dataModel).isEmpty)
    }

}
