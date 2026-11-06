//  RequestTabCloseTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
final class RequestTabCloseTests {

    private struct SaveFailed: Error {}

    private let suiteName = "RequestTabCloseTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let dataModel: DataModel
    private let request = Request(name: "List Users", urlTemplate: "https://example.com")

    init() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        self.defaults = defaults
        self.dataModel = try .inMemory(seed: Workspace(collections: [
            RequestCollection(name: "API", children: [CollectionItem(sortOrder: 0, node: .request(request))])
        ]))
    }

    isolated deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func snapshot() throws -> CollectionSnapshot {
        let context = ModelContext(dataModel.container)
        let requests = try context.fetch(FetchDescriptor<RequestModel>())
        return try CollectionSnapshot(
            tree: CollectionTree(
                collections: context.fetch(FetchDescriptor<CollectionModel>()),
                folders: context.fetch(FetchDescriptor<FolderModel>()),
                requests: requests
            ),
            requestIDs: Set(requests.map(\.id))
        )
    }

    private func openedTabs(saving save: @escaping RequestDrafts.Save = { _, _ in }) throws -> RequestTabsModel {
        let drafts = RequestDrafts(save: save)
        drafts.savedRequestDidChange(request)
        let tabs = RequestTabsModel(store: RequestTabStore(defaults: defaults, key: "Tabs"), drafts: drafts)
        try tabs.collectionDidChange(snapshot())
        tabs.open(request.id)
        return tabs
    }

    private func editedTabs(saving save: @escaping RequestDrafts.Save = { _, _ in }) throws -> RequestTabsModel {
        let tabs = try openedTabs(saving: save)
        tabs.drafts.update(request.id) { $0.url += "/more" }
        return tabs
    }

    @Test("A tab with no edits closes at once")
    func cleanTabCloses() throws {
        let tabs = try openedTabs()

        tabs.requestClose(request.id)

        #expect(tabs.openTabs.isEmpty)
        #expect(tabs.pendingClose == nil)
    }

    @Test("An edited tab stays open and asks")
    func editedTabAsks() throws {
        let tabs = try editedTabs()

        tabs.requestClose(request.id)

        #expect(tabs.openTabs.map(\.id) == [request.id])
        #expect(tabs.pendingClose?.name == "List Users")
    }

    @Test("Closing the selected tab asks too, because the menu and ⌘W come this way")
    func closeSelectedAsks() throws {
        let tabs = try editedTabs()

        tabs.closeSelected()

        #expect(tabs.openTabs.map(\.id) == [request.id])
        #expect(tabs.pendingClose != nil)
    }

    @Test("Save writes the draft and closes the tab")
    func saveCloses() async throws {
        var saved: RequestEdit?
        let tabs = try editedTabs { _, edit in saved = edit }

        tabs.requestClose(request.id)
        await tabs.saveAndClose(request.id)

        #expect(saved?.urlTemplate == "https://example.com/more")
        #expect(tabs.openTabs.isEmpty)
    }

    @Test("A failed Save leaves the tab open with its draft")
    func failedSaveLeavesTabOpen() async throws {
        let tabs = try editedTabs { _, _ in throw SaveFailed() }

        await tabs.saveAndClose(request.id)

        #expect(tabs.openTabs.map(\.id) == [request.id])
        #expect(tabs.drafts.isEdited(request.id))
    }

    @Test("Don't Save discards the draft and closes the tab")
    func dontSaveDiscards() throws {
        let tabs = try editedTabs()

        tabs.discardAndClose(request.id)

        #expect(tabs.openTabs.isEmpty)
        #expect(!tabs.drafts.isEdited(request.id))
    }

    @Test("A field that commits as its tab closes puts no edit back on the draft")
    func commitFromClosedTabIsIgnored() async throws {
        let tabs = try editedTabs()

        await tabs.saveAndClose(request.id)
        tabs.editDraft(request.id) { $0.url = "https://example.com/stale" }

        #expect(tabs.drafts.draft(for: request.id)?.url == "https://example.com/more")
        #expect(!tabs.drafts.isEdited(request.id))
    }

    @Test("An edit to the selected tab reaches its draft")
    func editReachesDraft() throws {
        let tabs = try openedTabs()

        tabs.editDraft(request.id) { $0.url = "https://example.com/typed" }

        #expect(tabs.drafts.draft(for: request.id)?.url == "https://example.com/typed")
    }

    @Test("A request that leaves the store drops its draft")
    func requestLeavingStoreDropsDraft() throws {
        let tabs = try editedTabs()

        try tabs.collectionDidChange(CollectionSnapshot(tree: snapshot().tree, requestIDs: []))

        #expect(tabs.drafts.draft(for: request.id) == nil)
        #expect(tabs.drafts.editedRequestCount == 0)
    }

}
