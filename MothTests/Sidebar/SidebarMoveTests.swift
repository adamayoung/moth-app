//  SidebarMoveTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
struct SidebarMoveTests {

    private let request = Request(name: "Request")
    private let inner = Folder(name: "Inner")
    private let outer: Folder
    private let collection: RequestCollection
    private let other = RequestCollection(name: "Other")
    private let tree: CollectionTree

    /// API > (Outer > Inner, Request), and Other.
    init() throws {
        let outer = Folder(name: "Outer", children: [CollectionItem(sortOrder: 0, node: .folder(inner))])
        let collection = RequestCollection(name: "API", children: [
            CollectionItem(sortOrder: 0, node: .folder(outer)),
            CollectionItem(sortOrder: 1, node: .request(request))
        ])
        self.outer = outer
        self.collection = collection
        let dataModel = try DataModel.inMemory(seed: Workspace(collections: [collection, other]))
        let context = ModelContext(dataModel.container)
        self.tree = try CollectionTree(
            collections: context.fetch(FetchDescriptor<CollectionModel>()),
            folders: context.fetch(FetchDescriptor<FolderModel>()),
            requests: context.fetch(FetchDescriptor<RequestModel>())
        )
    }

    @Test("A collection reorders among the collections")
    func collectionReorders() {
        let move = SidebarMove(
            moving: .collection(other.id),
            to: .root,
            before: .collection(collection.id),
            in: tree
        )

        #expect(move == .collection(other.id, before: collection.id))
    }

    @Test("A collection dropped at the end of the collections goes last")
    func collectionGoesLast() {
        let move = SidebarMove(moving: .collection(collection.id), to: .root, before: nil, in: tree)

        #expect(move == .collection(collection.id, before: nil))
    }

    @Test("A collection cannot go inside anything")
    func collectionStaysAtTheTop() {
        let intoCollection = SidebarMove(
            moving: .collection(other.id),
            to: .container(.collection(collection.id)),
            before: nil,
            in: tree
        )
        let intoFolder = SidebarMove(
            moving: .collection(other.id),
            to: .container(.folder(outer.id)),
            before: nil,
            in: tree
        )

        #expect(intoCollection == nil)
        #expect(intoFolder == nil)
    }

    @Test("A request or folder cannot sit beside the collections")
    func itemsStayInsideSomething() {
        #expect(SidebarMove(moving: .request(request.id), to: .root, before: nil, in: tree) == nil)
        #expect(SidebarMove(moving: .folder(outer.id), to: .root, before: nil, in: tree) == nil)
    }

    @Test("A request moves into a folder, ahead of the row it was dropped on")
    func requestMovesIntoAFolder() {
        let move = SidebarMove(
            moving: .request(request.id),
            to: .container(.folder(outer.id)),
            before: .folder(inner.id),
            in: tree
        )

        #expect(move == .item(.request(request.id), to: .folder(outer.id), before: .folder(inner.id)))
    }

    @Test("A folder moves to another collection")
    func folderMovesBetweenCollections() {
        let move = SidebarMove(
            moving: .folder(outer.id),
            to: .container(.collection(other.id)),
            before: nil,
            in: tree
        )

        #expect(move == .item(.folder(outer.id), to: .collection(other.id), before: nil))
    }

    @Test("A folder cannot go inside itself or anything beneath it")
    func folderStaysOutOfItself() {
        let intoItself = SidebarMove(
            moving: .folder(outer.id),
            to: .container(.folder(outer.id)),
            before: nil,
            in: tree
        )
        let beneathItself = SidebarMove(
            moving: .folder(outer.id),
            to: .container(.folder(inner.id)),
            before: nil,
            in: tree
        )

        #expect(intoItself == nil)
        #expect(beneathItself == nil)
    }

}
