//  ModelMappingTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

/// Reads back through a fresh context, so a value that only survives in memory fails.
struct ModelMappingTests {

    @Test("A workspace survives a round trip through the store")
    func workspaceRoundTrip() throws {
        let workspace = DomainFixtures.workspace()

        let saved = try Self.savedInStore(WorkspaceModel(workspace)) { try $0.asDomain() }

        #expect(saved == workspace)
    }

    @Test("A collection survives a round trip, with folders nested three levels down")
    func collectionRoundTrip() throws {
        let collection = DomainFixtures.collection()

        let saved = try Self.savedInStore(CollectionModel(collection, sortOrder: 0)) { try $0.asDomain() }

        #expect(saved == collection)
    }

    @Test("An environment survives a round trip")
    func environmentRoundTrip() throws {
        let environment = DomainFixtures.environment()

        let saved = try Self.savedInStore(EnvironmentModel(environment, sortOrder: 0)) { $0.asDomain() }

        #expect(saved == environment)
    }

    @Test("A request survives a round trip with every auth kind", arguments: DomainFixtures.auths)
    func requestRoundTripWithAuth(auth: Auth) throws {
        let request = DomainFixtures.request(auth: auth)

        let saved = try Self.savedInStore(RequestModel(request, sortOrder: 0)) { try $0.asDomain() }

        #expect(saved == request)
    }

    @Test("A request survives a round trip with every body kind", arguments: DomainFixtures.bodies)
    func requestRoundTripWithBody(body: RequestBody) throws {
        let request = DomainFixtures.request(body: body)

        let saved = try Self.savedInStore(RequestModel(request, sortOrder: 0)) { try $0.asDomain() }

        #expect(saved == request)
    }

    @Test("A variable survives a round trip with either kind of value", arguments: DomainFixtures.variableValues)
    func variableRoundTrip(value: VariableValue) throws {
        let variable = Variable(name: "host", value: value, isEnabled: false)

        let saved = try Self.savedInStore(VariableModel(variable, sortOrder: 0)) { $0.asDomain() }

        #expect(saved == variable)
    }

    @Test("A folder survives a round trip with its auth and children")
    func folderRoundTrip() throws {
        let folder = Folder(
            name: "Users",
            auth: .bearer(BearerAuth(token: DomainFixtures.reference)),
            children: [CollectionItem(sortOrder: 1, node: .request(DomainFixtures.request()))]
        )

        let saved = try Self.savedInStore(FolderModel(folder, sortOrder: 0)) { try $0.asDomain() }

        #expect(saved == folder)
    }

    @Test("A history entry survives a round trip")
    func historyEntryRoundTrip() throws {
        let entry = DomainFixtures.historyEntry()

        let saved = try Self.savedInStore(HistoryEntryModel(entry)) { try $0.asDomain() }

        #expect(saved == entry)
    }

    @Test("A history entry with no response survives a round trip")
    func historyEntryWithoutResponseRoundTrip() throws {
        let entry = HistoryEntry(
            request: DomainFixtures.request(),
            sentAt: Date(timeIntervalSinceReferenceDate: 1),
            duration: .zero
        )

        let saved = try Self.savedInStore(HistoryEntryModel(entry)) { try $0.asDomain() }

        #expect(saved == entry)
    }

    @Test("A history entry keeps its request's identifier in an attribute of its own")
    func historyEntryRefersToItsRequest() throws {
        let entry = DomainFixtures.historyEntry()

        let requestID = try Self.savedInStore(HistoryEntryModel(entry)) { $0.requestID }

        #expect(requestID == entry.request.id)
    }

    @Test("Collections, environments and variables keep their order")
    func siblingOrderSurvives() throws {
        let names = (0 ..< 12).map { "item \($0)" }
        let workspace = Workspace(
            collections: names.map { RequestCollection(name: $0) },
            environments: names.map { WorkspaceEnvironment(name: $0) },
            globals: names.map { Variable(name: $0, value: .plain(initial: "", current: "")) }
        )

        let saved = try Self.savedInStore(WorkspaceModel(workspace)) { try $0.asDomain() }

        #expect(saved.collections.map(\.name) == names)
        #expect(saved.environments.map(\.name) == names)
        #expect(saved.globals.map(\.name) == names)
    }

    @Test("Siblings with one sortOrder fall back to their id, so that every Mac agrees")
    func tiedSortOrderFallsBackToID() {
        let environments = (0 ..< 6).map { _ in WorkspaceEnvironment(name: "") }
        let rows = environments.map { EnvironmentModel($0, sortOrder: 0) }

        let sorted = rows.inSortOrder.map(\.id)

        #expect(sorted == environments.map(\.id).sorted())
    }

    @Test("A secret variable's row holds its reference and no value")
    func secretVariableHoldsOnlyItsReference() {
        let row = VariableModel(Variable(name: "key", value: .secret(DomainFixtures.reference)), sortOrder: 0)

        #expect(row.secretIdentifier == DomainFixtures.reference.identifier)
        #expect(row.initialValue.isEmpty)
        #expect(row.currentValue.isEmpty)
    }

    @Test("A row with no stored auth or settings maps to the defaults")
    func rowWithNoStoredValuesMapsToDefaults() throws {
        let request = try RequestModel().asDomain()
        let collection = try CollectionModel().asDomain()
        let folder = try FolderModel().asDomain()

        #expect(request.auth == .inherit)
        #expect(request.body == .none)
        #expect(request.settings == RequestSettings())
        #expect(collection.auth == .none)
        #expect(folder.auth == .inherit)
    }

    private static func savedInStore<Row: PersistentModel, Result>(
        _ row: Row,
        read: (Row) throws -> Result
    ) throws -> Result {
        let dataModel = try DataModel.inMemory()
        let writingContext = ModelContext(dataModel.container)
        writingContext.insert(row)
        try writingContext.save()

        let reader = ModelContext(dataModel.container)
        let saved = try #require(reader.fetch(FetchDescriptor<Row>()).first)
        return try read(saved)
    }

}
