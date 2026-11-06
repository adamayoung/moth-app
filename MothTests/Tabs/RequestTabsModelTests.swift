//  RequestTabsModelTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
final class RequestTabsModelTests {

    private let suiteName = "RequestTabsModelTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let store: RequestTabStore
    private let dataModel: DataModel

    private let inFolder = Request(name: "In Folder", method: .post)
    private let top = Request(name: "Top")
    private let last = Request(name: "Last", method: .delete)
    private let folder: Folder

    /// API > (Folder > In Folder, Top, Last).
    init() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let folder = Folder(name: "Folder", children: [
            CollectionItem(sortOrder: 0, node: .request(inFolder))
        ])
        let collection = RequestCollection(name: "API", children: [
            CollectionItem(sortOrder: 0, node: .folder(folder)),
            CollectionItem(sortOrder: 1, node: .request(top)),
            CollectionItem(sortOrder: 2, node: .request(last))
        ])
        self.defaults = defaults
        self.store = RequestTabStore(defaults: defaults, key: "Tabs")
        self.folder = folder
        self.dataModel = try .inMemory(seed: Workspace(collections: [collection]))
    }

    isolated deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func savedSnapshot() throws -> CollectionSnapshot {
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

    /// A model with its first snapshot, as a window has once the queries have delivered.
    private func openedModel() throws -> RequestTabsModel {
        let model = RequestTabsModel(store: store, drafts: RequestDrafts(writer: dataModel.writer))
        try model.collectionDidChange(savedSnapshot())
        return model
    }

    private func save(open requests: [Request], selecting selected: Request) {
        var tabs = RequestTabs()
        requests.forEach { tabs.open($0.id) }
        tabs.select(selected.id)
        store.save(tabs)
    }

    @Test("A tab shows the request's method and name")
    func tabShowsMethodAndName() throws {
        let model = try openedModel()

        model.open(inFolder.id)

        let tab = try #require(model.openTabs.first)
        #expect(tab.name == "In Folder")
        #expect(tab.method == .post)
        #expect(model.selectedTab == tab)
    }

    @Test("A tab follows a rename")
    func tabFollowsRename() async throws {
        let model = try openedModel()
        model.open(top.id)

        try await dataModel.writer.rename(.request(top.id), to: "Renamed")
        try model.collectionDidChange(savedSnapshot())

        #expect(model.openTabs.map(\.name) == ["Renamed"])
        #expect(model.selectedTab?.name == "Renamed")
    }

    @Test("A change through the model reaches the store")
    func changesReachTheStore() throws {
        let model = try openedModel()

        model.open(top.id)
        model.open(last.id)
        model.select(top.id)
        model.close(last.id)

        var expected = RequestTabs()
        expected.open(top.id)
        #expect(store.load() == expected)
    }

    @Test("A model restores its tabs and selection from the store")
    func restoresFromStore() throws {
        save(open: [top, last], selecting: top)

        let model = try openedModel()

        #expect(model.openTabs.map(\.name) == ["Top", "Last"])
        #expect(model.selectedTab?.name == "Top")
    }

    @Test("Closing the selected tab closes it and leaves the rest open")
    func closeSelected() throws {
        let model = try openedModel()
        model.open(top.id)
        model.open(last.id)

        model.closeSelected()

        #expect(model.openTabs.map(\.name) == ["Top"])
        #expect(model.selectedTab?.name == "Top")
    }

    @Test("A deleted request's tab closes, and the store forgets it")
    func deletedRequestClosesItsTab() async throws {
        let model = try openedModel()
        model.open(top.id)
        model.open(last.id)

        try await dataModel.writer.delete(.request(last.id))
        try model.collectionDidChange(savedSnapshot())

        #expect(model.openTabs.map(\.name) == ["Top"])
        #expect(store.load().ids == [top.id])
    }

    @Test("Deleting the selected request selects a neighbour")
    func deletingSelectedSelectsNeighbour() async throws {
        let model = try openedModel()
        model.open(top.id)
        model.open(last.id)
        model.select(top.id)

        try await dataModel.writer.delete(.request(top.id))
        try model.collectionDidChange(savedSnapshot())

        #expect(model.selectedTab?.name == "Last")
    }

    @Test("A deleted folder closes the tabs of the requests beneath it")
    func deletedFolderClosesItsRequestsTabs() async throws {
        let model = try openedModel()
        model.open(inFolder.id)
        model.open(top.id)

        try await dataModel.writer.delete(.folder(folder.id))
        try model.collectionDidChange(savedSnapshot())

        #expect(model.openTabs.map(\.name) == ["Top"])
    }

    @Test("A missing request's saved tab is dropped at launch")
    func missingSavedTabIsDropped() throws {
        let missing = Request(name: "Gone")
        save(open: [top, missing, last], selecting: last)

        let model = try openedModel()

        #expect(model.openTabs.map(\.name) == ["Top", "Last"])
        #expect(store.load().ids == [top.id, last.id])
    }

    @Test("A request out of the tree but still stored keeps its tab, which returns with it")
    func requestOutOfTheTreeKeepsItsTab() throws {
        let model = try openedModel()
        model.open(top.id)

        model.collectionDidChange(CollectionSnapshot(tree: .empty, requestIDs: [top.id]))
        #expect(model.openTabs.isEmpty)
        #expect(store.load().ids == [top.id])

        try model.collectionDidChange(savedSnapshot())
        #expect(model.openTabs.map(\.name) == ["Top"])
        #expect(model.selectedTab?.name == "Top")
    }

    @Test("A saved selection whose request has gone moves to a neighbour at launch")
    func missingSavedSelectionMoves() throws {
        let missing = Request(name: "Gone")
        save(open: [top, missing, last], selecting: missing)

        let model = try openedModel()

        #expect(model.selectedTab?.name == "Last")
    }

}
