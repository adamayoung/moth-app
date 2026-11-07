//  InheritedAuthMessageTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
struct InheritedAuthMessageTests {

    private let bearer = Auth.bearer(BearerAuth(token: SecretReference(identifier: "token")))

    private func model(holding collection: RequestCollection) throws -> (DataModel, RequestTabsModel) {
        let dataModel = try DataModel.inMemory(seed: Workspace(collections: [collection]))
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let tabs = RequestTabsModel(
            store: RequestTabStore(defaults: defaults, key: "Tabs"),
            drafts: .preview,
            responses: .preview,
            code: .preview
        )
        let context = dataModel.mainContext
        let requests = try context.fetch(FetchDescriptor<RequestModel>())
        try tabs.collectionDidChange(CollectionSnapshot(
            tree: CollectionTree(
                collections: context.fetch(FetchDescriptor<CollectionModel>()),
                folders: context.fetch(FetchDescriptor<FolderModel>()),
                requests: requests
            ),
            requestIDs: Set(requests.map(\.id))
        ))
        return (dataModel, tabs)
    }

    private func message(for request: Request, in collection: RequestCollection) throws -> String? {
        let (dataModel, tabs) = try model(holding: collection)
        tabs.open(request.id)
        return withExtendedLifetime(dataModel) {
            tabs.selectedTab?.inheritedAuth.message
        }
    }

    @Test("Auth from a folder names the folder")
    func throughAFolder() throws {
        let request = Request(name: "List")
        let folder = Folder(name: "Users", auth: bearer, children: [
            CollectionItem(sortOrder: 0, node: .request(request))
        ])
        let collection = RequestCollection(name: "API", children: [
            CollectionItem(sortOrder: 0, node: .folder(folder))
        ])

        #expect(try message(for: request, in: collection) == "Inherited from \u{201C}Users\u{201D}")
    }

    @Test("Auth from a collection names the collection, through a folder that inherits")
    func throughACollection() throws {
        let request = Request(name: "List")
        let folder = Folder(name: "Users", children: [CollectionItem(sortOrder: 0, node: .request(request))])
        let collection = RequestCollection(name: "API", auth: bearer, children: [
            CollectionItem(sortOrder: 0, node: .folder(folder))
        ])

        #expect(try message(for: request, in: collection) == "Inherited from \u{201C}API\u{201D}")
    }

    @Test("A folder set to No Auth leaves nothing to inherit, even with auth above it")
    func noAuthOnAFolder() throws {
        let request = Request(name: "List")
        let folder = Folder(name: "Users", auth: .none, children: [
            CollectionItem(sortOrder: 0, node: .request(request))
        ])
        let collection = RequestCollection(name: "API", auth: bearer, children: [
            CollectionItem(sortOrder: 0, node: .folder(folder))
        ])

        #expect(try message(for: request, in: collection) == "No auth to inherit")
    }

    @Test("A collection with no auth leaves nothing to inherit")
    func noAuthOnACollection() throws {
        let request = Request(name: "List")
        let collection = RequestCollection(name: "API", children: [
            CollectionItem(sortOrder: 0, node: .request(request))
        ])

        #expect(try message(for: request, in: collection) == "No auth to inherit")
    }

}
