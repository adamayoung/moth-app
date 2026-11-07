//  CurlImportModelTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import MothImport
import SwiftData
import Testing

@Suite("Import cURL")
@MainActor
final class CurlImportModelTests {

    private struct StoreRefusal: Error {}

    private static let invalid = "This isn\u{2019}t a valid cURL command."
    private static let failed = "Moth couldn\u{2019}t import this command. Nothing was added."

    private let suiteName = "CurlImportModelTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let dataModel: DataModel
    let sidebar: SidebarModel
    private let environments: EnvironmentsModel
    private let tabs: RequestTabsModel

    private let top = Request(name: "Top")
    private let folder = Folder(name: "Folder")
    let collection: RequestCollection
    private let second = RequestCollection(name: "Second")

    /// API > (Folder, Top), then Second.
    init() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let collection = RequestCollection(name: "API", children: [
            CollectionItem(sortOrder: 0, node: .folder(folder)),
            CollectionItem(sortOrder: 1, node: .request(top))
        ])
        let dataModel = try DataModel.inMemory(seed: Workspace(collections: [collection, second]))
        let secretStore = InMemorySecretStore()

        self.defaults = defaults
        self.collection = collection
        self.dataModel = dataModel
        self.sidebar = SidebarModel(writer: dataModel.writer, secretStore: secretStore)
        self.environments = EnvironmentsModel(
            writer: dataModel.writer,
            secretStore: secretStore,
            activeEnvironment: ActiveEnvironment(inMemory: nil)
        )
        self.tabs = RequestTabsModel(
            store: RequestTabStore(defaults: defaults, key: "Tabs"),
            drafts: RequestDrafts(writer: dataModel.writer, secretStore: secretStore),
            responses: .preview
        )
    }

    isolated deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func makeModel(
        secretStore: any SecretStore = InMemorySecretStore(),
        createRequest: (@Sendable (Request, TreeContainerID) async throws -> Void)? = nil
    ) -> ImportModel {
        let writer = dataModel.writer
        return ImportModel(
            source: .panel,
            secretStore: secretStore,
            sidebar: sidebar,
            environments: environments,
            write: { try await writer.create($0) },
            createRequest: createRequest ?? { try await writer.createRequest($0, in: $1) },
            openRequest: { [tabs] in tabs.open($0) }
        )
    }

    /// Stands in for `@Query`, which delivers a writer's save to the views some time after the write returns.
    func deliverRows() throws {
        let context = ModelContext(dataModel.container)
        let requests = try context.fetch(FetchDescriptor<RequestModel>())
        let tree = try CollectionTree(
            collections: context.fetch(FetchDescriptor<CollectionModel>()),
            folders: context.fetch(FetchDescriptor<FolderModel>()),
            requests: requests
        )
        sidebar.treeDidChange(tree)
        tabs.collectionDidChange(CollectionSnapshot(tree: tree, requestIDs: Set(requests.map(\.id))))
    }

    func importing(_ text: String, into model: ImportModel) async {
        model.beginCurlImport()
        model.curlText = text
        await model.importCurl()
    }

    private func parentOfImportedRequest() throws -> TreeNodeID {
        let tab = try #require(tabs.selectedTab)
        return try #require(sidebar.tree.ancestors(of: .request(tab.id)).last)
    }

    @Test(
        "With nothing selected the request goes to the first collection, and with no collection nowhere",
        arguments: [true, false]
    )
    func canImportNeedsACollection(hasCollections: Bool) throws {
        if hasCollections {
            try deliverRows()
        }

        #expect(makeModel().canImportCurl == hasCollections)
    }

    @Test("A selected collection receives the request")
    func destinationIsTheSelectedCollection() async throws {
        try deliverRows()
        sidebar.selection = .collection(second.id)

        await importing("curl https://a.example/users", into: makeModel())
        try deliverRows()

        #expect(try parentOfImportedRequest() == .collection(second.id))
    }

    @Test("A selected folder receives the request")
    func destinationIsTheSelectedFolder() async throws {
        try deliverRows()
        sidebar.selection = .folder(folder.id)

        await importing("curl https://a.example/users", into: makeModel())
        try deliverRows()

        #expect(try parentOfImportedRequest() == .folder(folder.id))
    }

    @Test("A selected request's parent receives the request, beside it")
    func destinationIsBesideTheSelectedRequest() async throws {
        try deliverRows()
        sidebar.selection = .request(top.id)

        await importing("curl https://a.example/users", into: makeModel())
        try deliverRows()

        #expect(try parentOfImportedRequest() == .collection(collection.id))
    }

    @Test("With nothing selected, the first collection receives the request")
    func destinationIsTheFirstCollection() async throws {
        try deliverRows()

        await importing("curl https://a.example/users", into: makeModel())
        try deliverRows()

        #expect(try parentOfImportedRequest() == .collection(collection.id))
    }

    @Test("The request opens in a tab that survives the query's delivery, and the sheet closes")
    func opensATab() async throws {
        try deliverRows()
        let model = makeModel()

        await importing("curl -X POST https://a.example/users", into: model)
        try deliverRows()

        let tab = try #require(tabs.selectedTab)
        #expect(tab.name == "POST /users")
        #expect(tabs.openTabs.count == 1)
        #expect(!model.isEnteringCurl)
        #expect(model.report == nil)
    }

    @Test("The new request takes the selection, with its parents expanded and no rename")
    func revealsTheRequest() async throws {
        try deliverRows()
        sidebar.selection = .folder(folder.id)

        await importing("curl https://a.example/users", into: makeModel())
        try deliverRows()

        let tab = try #require(tabs.selectedTab)
        #expect(sidebar.selection == .request(tab.id))
        #expect(sidebar.expanded.isSuperset(of: [.collection(collection.id), .folder(folder.id)]))
        #expect(sidebar.renaming == nil)
    }

    @Test("Import needs some text", arguments: ["", "  ", "\n\t\n"])
    func blankTextCannotBeSubmitted(text: String) throws {
        try deliverRows()
        let model = makeModel()

        model.beginCurlImport()
        model.curlText = text

        #expect(model.isEnteringCurl)
        #expect(!model.canSubmitCurl)
    }

    @Test("Any text can be submitted")
    func textCanBeSubmitted() throws {
        try deliverRows()
        let model = makeModel()

        model.beginCurlImport()
        model.curlText = "hello"

        #expect(model.canSubmitCurl)
    }

    @Test("Text that isn't a command shows the message, keeps the sheet and adds nothing")
    func invalidTextKeepsTheSheet() async throws {
        try deliverRows()
        let model = makeModel()

        await importing("hello", into: model)
        try deliverRows()

        #expect(model.isEnteringCurl)
        #expect(model.curlProblem?.message == Self.invalid)
        #expect(model.curlText == "hello")
        #expect(tabs.openTabs.isEmpty)
    }

    @Test("Opening the sheet again starts clean")
    func reopeningStartsClean() async throws {
        try deliverRows()
        let model = makeModel()
        await importing("hello", into: model)
        model.cancelCurlImport()

        model.beginCurlImport()

        #expect(model.curlText.isEmpty)
        #expect(model.curlProblem == nil)
    }

    @Test("Cancel closes the sheet and imports nothing")
    func cancelCloses() throws {
        try deliverRows()
        let model = makeModel()
        model.beginCurlImport()

        model.cancelCurlImport()

        #expect(!model.isEnteringCurl)
        #expect(tabs.openTabs.isEmpty)
    }

    @Test("Ignored flags reach the report, after the request has opened")
    func ignoredFlagsReachTheReport() async throws {
        try deliverRows()
        let model = makeModel()

        await importing("curl -s --data @body.json https://a.example/users", into: model)
        try deliverRows()

        #expect(model.report?.message == "Imported \u{201C}POST /users\u{201D}.")
        #expect(model.report?.skipped == "Ignored: -s and --data @body.json")
        #expect(tabs.selectedTab?.name == "POST /users")
    }

    @Test("A failed write says so, keeps the text, and leaves no secret")
    func failedWriteKeepsTheSheet() async throws {
        try deliverRows()
        let secretStore = RecordingSecretStore()
        let model = makeModel(secretStore: secretStore, createRequest: { _, _ in throw StoreRefusal() })

        await importing("curl -u user:pass https://a.example/users", into: model)

        #expect(model.isEnteringCurl)
        #expect(model.curlProblem?.message == Self.failed)
        #expect(secretStore.values.isEmpty)
        #expect(!model.isImporting)
    }

    @Test("A credential reaches the secret store through the importer")
    func credentialsReachTheSecretStore() async throws {
        try deliverRows()
        let secretStore = RecordingSecretStore()

        await importing("curl -u user:pass https://a.example/users", into: makeModel(secretStore: secretStore))

        #expect(Array(secretStore.values.values) == ["pass"])
    }

}
