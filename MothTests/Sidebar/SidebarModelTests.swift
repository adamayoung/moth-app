//  SidebarModelTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
struct SidebarModelTests {

    let dataModel: DataModel
    let model: SidebarModel

    let deep = Request(name: "Deep")
    let shallow = Request(name: "Shallow", method: .post)
    let top = Request(name: "Top")
    let inner: Folder
    let folder: Folder
    let empty = Folder(name: "Empty")
    let collection: RequestCollection
    let other = RequestCollection(name: "Other")

    /// API > (Folder > (Inner > Deep, Shallow), Empty, Top), and Other.
    init() throws {
        let inner = Folder(name: "Inner", children: [
            CollectionItem(sortOrder: 0, node: .request(deep))
        ])
        let folder = Folder(name: "Folder", children: [
            CollectionItem(sortOrder: 0, node: .folder(inner)),
            CollectionItem(sortOrder: 1, node: .request(shallow))
        ])
        let collection = RequestCollection(name: "API", children: [
            CollectionItem(sortOrder: 0, node: .folder(folder)),
            CollectionItem(sortOrder: 1, node: .folder(empty)),
            CollectionItem(sortOrder: 2, node: .request(top))
        ])
        self.inner = inner
        self.folder = folder
        self.collection = collection
        self.dataModel = try .inMemory(seed: Workspace(collections: [collection, other]))
        self.model = SidebarModel(writer: dataModel.writer, secretStore: InMemorySecretStore())
        try deliverTree()
    }

    private func savedTree() throws -> CollectionTree {
        let context = ModelContext(dataModel.container)
        return try CollectionTree(
            collections: context.fetch(FetchDescriptor<CollectionModel>()),
            folders: context.fetch(FetchDescriptor<FolderModel>()),
            requests: context.fetch(FetchDescriptor<RequestModel>())
        )
    }

    /// Stands in for `@Query`, which delivers a writer's save to the view some time after the write returns.
    func deliverTree() throws {
        try model.treeDidChange(savedTree())
    }

    @Test("New Collection adds a collection, selected, with its name ready to edit")
    func newCollection() async throws {
        await model.newCollection()
        try deliverTree()

        let selection = try #require(model.selection)
        #expect(model.tree.node(selection)?.name == "New Collection")
        #expect(model.tree.roots.count == 3)
        #expect(model.renaming == selection)
    }

    @Test("New Folder adds a folder, selected and ready to edit, and opens its parent")
    func newFolder() async throws {
        model.expanded = []

        await model.newFolder(in: .folder(inner.id))
        try deliverTree()

        let selection = try #require(model.selection)
        #expect(model.tree.node(selection)?.name == "New Folder")
        #expect(model.tree.ancestors(of: selection).last == .folder(inner.id))
        #expect(model.renaming == selection)
        #expect(model.expanded == [.collection(collection.id), .folder(folder.id), .folder(inner.id)])
    }

    @Test("New Request adds a GET request, selected and ready to edit, and opens its parent")
    func newRequest() async throws {
        await model.newRequest(in: .collection(other.id))
        try deliverTree()

        let selection = try #require(model.selection)
        let node = try #require(model.tree.node(selection))
        #expect(node.name == "New Request")
        #expect(node.method == .get)
        #expect(model.tree.ancestors(of: selection) == [.collection(other.id)])
        #expect(model.renaming == selection)
        #expect(model.expanded == [.collection(other.id)])
    }

    @Test("A new item that fails to save selects nothing and starts no rename")
    func failedCreateChangesNothing() async {
        await model.newFolder(in: .folder(UUID()))

        #expect(model.selection == nil)
        #expect(model.renaming == nil)
    }

    @Test("A row made a moment ago keeps its selection until the query delivers it")
    func undeliveredRowKeepsItsSelection() async throws {
        let staleTree = model.tree

        await model.newCollection()
        let selection = try #require(model.selection)
        model.treeDidChange(staleTree)

        #expect(model.selection == selection)
        #expect(model.renaming == selection)
    }

    @Test("With nothing selected, File > New has nowhere to put a new item")
    func nothingSelectedHasNoContainer() {
        #expect(model.newItemContainer == nil)
    }

    @Test("File > New acts on a selected collection or folder")
    func selectedContainerIsTheTarget() {
        model.selection = .collection(collection.id)
        #expect(model.newItemContainer == .collection(collection.id))

        model.selection = .folder(folder.id)
        #expect(model.newItemContainer == .folder(folder.id))
    }

    @Test("File > New acts on a selected request's parent")
    func selectedRequestTargetsItsParent() {
        model.selection = .request(shallow.id)
        #expect(model.newItemContainer == .folder(folder.id))

        model.selection = .request(top.id)
        #expect(model.newItemContainer == .collection(collection.id))
    }

    @Test("A selection the tree cannot place has nowhere to put a new item")
    func unknownRequestHasNoContainer() {
        model.selection = .request(UUID())

        #expect(model.newItemContainer == nil)
    }

    @Test("Asking to delete a collection counts every request beneath it")
    func deletionCountsAcollection() throws {
        let node = try #require(model.tree.node(.collection(collection.id)))

        model.requestDeletion(of: node)

        #expect(model.pendingDeletion == PendingDeletion(
            id: .collection(collection.id),
            name: "API",
            requestsToMention: 3
        ))
    }

    @Test("Asking to delete a folder with one request mentions that one")
    func deletionCountsAFolder() throws {
        let node = try #require(model.tree.node(.folder(inner.id)))

        model.requestDeletion(of: node)

        #expect(model.pendingDeletion?.requestsToMention == 1)
    }

    @Test("Asking to delete a folder with no requests mentions none")
    func deletionOfAnEmptyFolderMentionsNone() throws {
        let node = try #require(model.tree.node(.folder(empty.id)))

        model.requestDeletion(of: node)

        #expect(model.pendingDeletion?.requestsToMention == nil)
    }

    @Test("Asking to delete a request mentions no count")
    func deletionOfARequestMentionsNone() throws {
        let node = try #require(model.tree.node(.request(top.id)))

        model.requestDeletion(of: node)

        #expect(model.pendingDeletion?.requestsToMention == nil)
    }

    @Test("After deleting a selected request, selection moves to its parent")
    func deleteMovesSelectionToParent() async throws {
        model.selection = .request(shallow.id)
        let node = try #require(model.tree.node(.request(shallow.id)))
        model.requestDeletion(of: node)
        let deletion = try #require(model.pendingDeletion)

        await model.confirmDeletion(deletion)
        try deliverTree()

        #expect(model.selection == .folder(folder.id))
        #expect(!model.tree.contains(.request(shallow.id)))
    }

    @Test("After deleting a selected collection, nothing is selected")
    func deleteOfACollectionClearsSelection() async throws {
        model.selection = .collection(collection.id)
        let node = try #require(model.tree.node(.collection(collection.id)))
        model.requestDeletion(of: node)
        let deletion = try #require(model.pendingDeletion)

        await model.confirmDeletion(deletion)
        try deliverTree()

        #expect(model.selection == nil)
    }

    @Test("Deleting a row other than the selected one leaves selection alone")
    func deleteElsewhereKeepsSelection() async throws {
        model.selection = .request(shallow.id)
        let node = try #require(model.tree.node(.request(top.id)))
        model.requestDeletion(of: node)
        let deletion = try #require(model.pendingDeletion)

        await model.confirmDeletion(deletion)
        try deliverTree()

        #expect(model.selection == .request(shallow.id))
    }

    @Test("A sync that removes the selected row moves selection, and ends a rename of that row")
    func syncRemovalMovesSelection() async throws {
        model.selection = .request(deep.id)
        await model.beginRename(of: .request(deep.id))

        try await dataModel.writer.delete(.folder(folder.id))
        try deliverTree()

        #expect(model.selection == .collection(collection.id))
        #expect(model.renaming == nil)
    }

    @Test("A move reaches the store, and a selected row keeps its selection as it moves")
    func moveKeepsSelection() async throws {
        model.selection = .request(top.id)

        await model.move(.request(top.id), to: .container(.folder(empty.id)), before: nil)
        try deliverTree()

        #expect(model.tree.ancestors(of: .request(top.id)).last == .folder(empty.id))
        #expect(model.selection == .request(top.id))
    }

    @Test("A drop the tree cannot hold leaves everything where it was")
    func invalidMoveChangesNothing() async throws {
        let before = model.tree

        await model.move(.folder(folder.id), to: .container(.folder(inner.id)), before: nil)
        try deliverTree()

        #expect(model.tree == before)
    }

    @Test("A drop lands ahead of the row at its offset")
    func dropLandsAtItsOffset() async throws {
        await model.drop([.request(top.id)], on: .container(.folder(folder.id)), atOffset: 1)
        try deliverTree()

        let children = try #require(model.tree.node(.folder(folder.id))).children
        #expect(children.map(\.name) == ["Inner", "Top", "Shallow"])
    }

    @Test("A drop at the end of a parent goes last")
    func dropAtTheEndGoesLast() async throws {
        await model.drop([.folder(empty.id)], on: .container(.collection(collection.id)), atOffset: 3)
        try deliverTree()

        let children = try #require(model.tree.node(.collection(collection.id))).children
        #expect(children.map(\.name) == ["Folder", "Top", "Empty"])
    }

    @Test("A collection dropped at the top of the collections goes first")
    func dropReordersCollections() async throws {
        await model.drop([.collection(other.id)], on: .root, atOffset: 0)
        try deliverTree()

        #expect(model.tree.roots.map(\.name) == ["Other", "API"])
    }

    @Test("The empty state waits for the first tree, so a launch with collections never shows it")
    func emptyStateWaitsForTheFirstTree() {
        let unfed = SidebarModel(writer: dataModel.writer, secretStore: InMemorySecretStore())

        #expect(!unfed.showsEmptyState)

        unfed.treeDidChange(.empty)

        #expect(unfed.showsEmptyState)
    }

    @Test("A tree with collections shows no empty state")
    func collectionsHideTheEmptyState() {
        #expect(!model.showsEmptyState)
    }

}
