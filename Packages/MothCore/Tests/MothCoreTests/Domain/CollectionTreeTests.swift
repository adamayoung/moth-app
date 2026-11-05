//  CollectionTreeTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct CollectionTreeTests {

    private func requestItem(_ name: String, sortOrder: Int, id: UUID = UUID()) -> CollectionItem {
        CollectionItem(sortOrder: sortOrder, node: .request(Request(id: id, name: name)))
    }

    private func names(of items: [CollectionItem]) -> [String] {
        items.map { item in
            switch item.node {
            case .folder(let folder): folder.name
            case .request(let request): request.name
            }
        }
    }

    @Test("A collection's children come back in sort order, whatever order they were given")
    func collectionChildrenAreOrdered() {
        let collection = RequestCollection(
            name: "API",
            children: [
                requestItem("Third", sortOrder: 2),
                requestItem("First", sortOrder: 0),
                requestItem("Second", sortOrder: 1)
            ]
        )

        #expect(names(of: collection.children) == ["First", "Second", "Third"])
    }

    @Test("A folder's children come back in sort order, whatever order they were given")
    func folderChildrenAreOrdered() {
        let folder = Folder(
            name: "Users",
            children: [requestItem("Second", sortOrder: 1), requestItem("First", sortOrder: 0)]
        )

        #expect(names(of: folder.children) == ["First", "Second"])
    }

    @Test("Adding a child to a collection keeps the children in order")
    func addingToACollectionKeepsTheOrder() {
        var collection = RequestCollection(name: "API", children: [requestItem("Second", sortOrder: 1)])

        collection.children.append(requestItem("First", sortOrder: 0))

        #expect(names(of: collection.children) == ["First", "Second"])
    }

    @Test("Adding a child to a folder keeps the children in order")
    func addingToAFolderKeepsTheOrder() {
        var folder = Folder(name: "Users", children: [requestItem("Second", sortOrder: 1)])

        folder.children.append(requestItem("First", sortOrder: 0))

        #expect(names(of: folder.children) == ["First", "Second"])
    }

    @Test("Equal sort orders fall back to the id, so every device agrees after a sync")
    func equalOrdersFallBackToTheID() throws {
        let lower = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let higher = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))

        let collection = RequestCollection(
            name: "API",
            children: [requestItem("Higher", sortOrder: 0, id: higher), requestItem("Lower", sortOrder: 0, id: lower)]
        )

        #expect(names(of: collection.children) == ["Lower", "Higher"])
    }

    @Test("A folder inside a folder keeps its own children in order")
    func nestedFoldersKeepTheirOrder() throws {
        let inner = Folder(
            name: "Inner",
            children: [requestItem("Second", sortOrder: 1), requestItem("First", sortOrder: 0)]
        )
        let outer = Folder(
            name: "Outer",
            children: [requestItem("After", sortOrder: 1), CollectionItem(sortOrder: 0, node: .folder(inner))]
        )
        let collection = RequestCollection(name: "API", children: [CollectionItem(sortOrder: 0, node: .folder(outer))])

        let keptOuter = try #require(collection.children.first)
        guard case .folder(let outerFolder) = keptOuter.node else {
            Issue.record("Expected the outer folder")
            return
        }

        #expect(names(of: outerFolder.children) == ["Inner", "After"])

        let keptInner = try #require(outerFolder.children.first)
        guard case .folder(let innerFolder) = keptInner.node else {
            Issue.record("Expected the inner folder")
            return
        }

        #expect(names(of: innerFolder.children) == ["First", "Second"])
    }

    @Test("A child's id is its request's id")
    func requestChildSharesItsID() {
        let request = Request(name: "List Users")

        #expect(CollectionItem(sortOrder: 0, node: .request(request)).id == request.id)
    }

    @Test("A child's id is its folder's id")
    func folderChildSharesItsID() {
        let folder = Folder(name: "Users")

        #expect(CollectionItem(sortOrder: 0, node: .folder(folder)).id == folder.id)
    }

    @Test("A new folder inherits auth, and a new collection has none")
    func authDefaults() {
        #expect(Folder(name: "Users").auth == .inherit)
        #expect(RequestCollection(name: "API").auth == .none)
    }

    @Test("Folders and collections keep the auth set on them")
    func keepsItsAuth() {
        let auth = Auth.bearer(BearerAuth(token: SecretReference()))

        #expect(Folder(name: "Users", auth: auth).auth == auth)
        #expect(RequestCollection(name: "API", auth: auth).auth == auth)
    }

    @Test("A collection keeps its variables")
    func collectionKeepsItsVariables() {
        let variable = Variable(name: "host", value: .plain(initial: "a", current: "b"))

        #expect(RequestCollection(name: "API", variables: [variable]).variables == [variable])
    }

}
