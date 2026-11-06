//  ImportModelTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import MothImport
import SwiftData
import Testing

@Suite("Import model, from snippets because each test needs only a file of a known shape")
@MainActor
struct ImportModelTests {

    private struct StoreRefusal: Error {}

    private static let collection = Data(#"""
    {
        "info": {
            "name": "Snippet",
            "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
        },
        "item": [{
            "name": "a",
            "event": [{ "listen": "test", "script": { "exec": ["pm.test();"] } }],
            "request": { "auth": { "type": "bearer", "bearer": [{ "key": "token", "value": "secret" }] } }
        }]
    }
    """#.utf8)

    private static let environment = Data(#"{ "name": "Staging", "values": [{ "key": "a", "value": "b" }] }"#.utf8)

    let dataModel: DataModel
    let sidebar: SidebarModel
    let environments: EnvironmentsModel

    init() throws {
        self.dataModel = try .inMemory()
        self.sidebar = SidebarModel(writer: dataModel.writer, secretStore: InMemorySecretStore())
        self.environments = EnvironmentsModel(
            writer: dataModel.writer,
            secretStore: InMemorySecretStore(),
            activeEnvironment: ActiveEnvironment(inMemory: nil)
        )
    }

    private func makeModel(
        source: ImportFileSource = .panel,
        secretStore: any SecretStore = InMemorySecretStore(),
        write: (@Sendable (PostmanImportContent) async throws -> Void)? = nil
    ) -> ImportModel {
        let writer = dataModel.writer
        return ImportModel(
            source: source,
            secretStore: secretStore,
            sidebar: sidebar,
            environments: environments,
            write: write ?? { try await writer.create($0) }
        )
    }

    private func savedCollectionNames() throws -> [String] {
        try ModelContext(dataModel.container).fetch(FetchDescriptor<CollectionModel>()).map(\.name)
    }

    /// Stands in for `@Query`, which delivers a writer's save to the view some time after the write returns.
    private func deliverRows() throws {
        let context = ModelContext(dataModel.container)
        try sidebar.treeDidChange(CollectionTree(
            collections: context.fetch(FetchDescriptor<CollectionModel>()),
            folders: context.fetch(FetchDescriptor<FolderModel>()),
            requests: context.fetch(FetchDescriptor<RequestModel>())
        ))
        try environments.rowsDidChange(EnvironmentSummary.list(
            environments: context.fetch(FetchDescriptor<EnvironmentModel>()),
            variables: context.fetch(FetchDescriptor<VariableModel>())
        ))
    }

    @Test("A collection reaches the store and the report says what came across")
    func importsACollection() async throws {
        let model = makeModel()

        await model.importData(Self.collection)

        #expect(try savedCollectionNames() == ["Snippet"])
        #expect(model.report?.message == "Imported \u{201C}Snippet\u{201D}: 1 request, 0 folders.")
        #expect(model.report?.skipped == "Skipped 1 script.")
        #expect(!model.isImporting)
    }

    @Test("An environment reaches the store and the report names its variables")
    func importsAnEnvironment() async throws {
        let model = makeModel()

        await model.importData(Self.environment)
        try deliverRows()

        #expect(environments.rows.map(\.name) == ["Staging"])
        #expect(model.report?.message == "Imported \u{201C}Staging\u{201D}: 1 variable.")
        #expect(model.report?.skipped == nil)
    }

    @Test("A failed store write writes nothing, leaves no secret, and says so")
    func failedStoreWriteLeavesNothing() async throws {
        let secretStore = RecordingSecretStore()
        let model = makeModel(secretStore: secretStore, write: { _ in throw StoreRefusal() })

        await model.importData(Self.collection)

        #expect(try savedCollectionNames().isEmpty)
        #expect(await secretStore.values.isEmpty)
        #expect(model.report?.message == "Moth couldn\u{2019}t import this file. Nothing was added.")
        #expect(!model.isImporting)
    }

    @Test("A file of another kind is refused with the rejection message")
    func rejectsAnotherKindOfFile() async throws {
        let model = makeModel()

        await model.importData(Data("not json".utf8))

        #expect(try savedCollectionNames().isEmpty)
        #expect(model.report?.message == "This file isn\u{2019}t a Postman Collection v2.1 or Environment.")
    }

    @Test("A file that can't be read says the import failed")
    func unreadableFileFails() async {
        let model = makeModel()

        await model.fileChosen(.success(URL(filePath: "/nonexistent/moth-import.json")))

        #expect(model.report?.message == "Moth couldn\u{2019}t import this file. Nothing was added.")
    }

    @Test("A chosen file is read and imported")
    func importsAChosenFile() async throws {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).json")
        try Self.collection.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let model = makeModel()

        await model.fileChosen(.success(url))

        #expect(try savedCollectionNames() == ["Snippet"])
    }

    @Test("Cancelling the panel reports nothing")
    func cancelledPanelReportsNothing() async {
        let model = makeModel()

        await model.fileChosen(.failure(CocoaError(.userCancelled)))

        #expect(model.report == nil)
    }

    @Test("A name already in the store gets a suffix")
    func avoidsExistingNames() async throws {
        let model = makeModel()
        await model.importData(Self.collection)
        await model.importData(Self.environment)
        try deliverRows()

        await model.importData(Self.collection)
        await model.importData(Self.environment)
        try deliverRows()

        #expect(sidebar.collectionNames == ["Snippet", "Snippet 2"])
        #expect(environments.names == ["Staging", "Staging 2"])
    }

    @Test("The panel source opens the panel")
    func panelSourceOpensThePanel() async {
        let model = makeModel(source: .panel)

        await model.chooseFile()

        #expect(model.isChoosingFile)
        #expect(!model.canImport)
    }

    @Test("A UI test's source skips the panel and imports its bytes")
    func uiTestSourceSkipsThePanel() async throws {
        let model = makeModel(source: .uiTest(Self.collection))

        await model.chooseFile()

        #expect(!model.isChoosingFile)
        #expect(try savedCollectionNames() == ["Snippet"])
    }

    @Test("Import is unavailable until the report is dismissed")
    func reportBlocksAnotherImport() async {
        let model = makeModel()
        #expect(model.canImport)

        await model.importData(Self.environment)
        #expect(!model.canImport)

        model.report = nil
        #expect(model.canImport)
    }

    @Test("Import is unavailable while another sheet or alert is up")
    func otherPresentationsBlockImport() {
        let model = makeModel()

        sidebar.presentedVariables = VariableSheetTarget(scope: .globals, title: "Globals")
        #expect(!model.canImport)
        sidebar.presentedVariables = nil

        sidebar.pendingDeletion = PendingDeletion(id: .collection(UUID()), name: "API", requestsToMention: nil)
        #expect(!model.canImport)
        sidebar.pendingDeletion = nil

        environments.pendingDeletion = EnvironmentSummary(id: UUID(), name: "Staging", variableCount: 0)
        #expect(!model.canImport)
        environments.pendingDeletion = nil

        #expect(model.canImport)
    }

    @Test("Choosing a file does nothing during an import, as the menu's state can lag the model", .timeLimit(.minutes(1)))
    func chooseFileIsRefusedDuringAnImport() async {
        let secretStore = ThreadHoldingSecretStore()
        let model = makeModel(secretStore: secretStore)

        let importing = Task { await model.importData(Self.collection) }
        await secretStore.waitUntilHolding()
        await model.chooseFile()
        secretStore.letGo()
        await importing.value

        #expect(!model.isChoosingFile)
    }

    @Test("A long import runs off the main actor, and shows Importing\u{2026} until it ends", .timeLimit(.minutes(1)))
    func longImportLeavesTheMainActorFree() async {
        let secretStore = ThreadHoldingSecretStore()
        let model = makeModel(secretStore: secretStore)

        let importing = Task { await model.importData(Self.collection) }
        await secretStore.waitUntilHolding()

        #expect(model.isImporting)
        #expect(!model.canImport)
        #expect(model.report == nil)

        secretStore.letGo()
        await importing.value

        #expect(secretStore.heldOffTheMainThreadUntilReleased)
        #expect(!model.isImporting)
        #expect(model.report != nil)
    }

}
