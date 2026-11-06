//  CollectionTreeInheritedAuthTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

struct CollectionTreeInheritedAuthTests {

    private let bearer = Auth.bearer(BearerAuth(token: SecretReference(identifier: "token")))
    private let digest = Auth.digest(
        DigestAuth(username: "ada", password: SecretReference(identifier: "digest"))
    )
    private let request = Request(name: "List")

    /// Collection "API" > Folder "Outer" > Folder "Inner" > request.
    private func tree(collection: Auth, outer: Auth, inner: Auth) throws -> (DataModel, CollectionTree) {
        let innerFolder = Folder(name: "Inner", auth: inner, children: [TreeFixtures.item(0, request)])
        let outerFolder = Folder(name: "Outer", auth: outer, children: [TreeFixtures.item(0, innerFolder)])
        let dataModel = try TreeFixtures.dataModel(holding: RequestCollection(
            name: "API",
            auth: collection,
            children: [TreeFixtures.item(0, outerFolder)]
        ))
        return try (dataModel, CollectionTree(savedIn: dataModel))
    }

    @Test("A request inherits from the nearest folder that sets auth")
    func nearestFolder() throws {
        let (_, tree) = try tree(collection: .none, outer: .inherit, inner: bearer)

        #expect(tree.inheritedAuth(of: .request(request.id)) == .from("Inner"))
    }

    @Test("A request inherits through folders that inherit, to the collection")
    func throughFoldersToTheCollection() throws {
        let (_, tree) = try tree(collection: bearer, outer: .inherit, inner: .inherit)

        #expect(tree.inheritedAuth(of: .request(request.id)) == .from("API"))
    }

    @Test("An auth the editor can't change still counts as where it comes from")
    func unsupportedKindCounts() throws {
        let (_, tree) = try tree(collection: .none, outer: digest, inner: .inherit)

        #expect(tree.inheritedAuth(of: .request(request.id)) == .from("Outer"))
    }

    @Test("A collection with no auth leaves nothing to inherit")
    func collectionWithNoAuth() throws {
        let (_, tree) = try tree(collection: .none, outer: .inherit, inner: .inherit)

        #expect(tree.inheritedAuth(of: .request(request.id)) == .nothing)
    }

    @Test("A folder with no auth stops the walk, even with auth above it")
    func folderWithNoAuthStops() throws {
        let (_, tree) = try tree(collection: bearer, outer: .none, inner: .inherit)

        #expect(tree.inheritedAuth(of: .request(request.id)) == .nothing)
    }

    @Test("A collection set to inherit has nothing above it")
    func collectionThatInherits() throws {
        let (_, tree) = try tree(collection: .inherit, outer: .inherit, inner: .inherit)

        #expect(tree.inheritedAuth(of: .request(request.id)) == .nothing)
    }

    @Test("A folder asks about what is above it, not about itself")
    func folderLooksAbove() throws {
        let (dataModel, tree) = try tree(collection: bearer, outer: .inherit, inner: digest)
        let folders = try TreeFixtures.savedRows(FolderModel.self, in: dataModel)
        let inner = try #require(folders.first { $0.name == "Inner" })

        #expect(tree.inheritedAuth(of: .folder(inner.id)) == .from("API"))
    }

    @Test("A collection has nothing to inherit")
    func collectionHasNothingAbove() throws {
        let (_, tree) = try tree(collection: bearer, outer: .inherit, inner: .inherit)
        let root = try #require(tree.roots.first)

        #expect(tree.inheritedAuth(of: root.id) == .nothing)
    }

    @Test("A container's node holds its auth")
    func nodeHoldsAuth() throws {
        let (_, tree) = try tree(collection: bearer, outer: .none, inner: .inherit)
        let root = try #require(tree.roots.first)
        let outer = try #require(root.children.first)

        #expect(root.auth == bearer)
        #expect(outer.auth == Auth.none)
    }

    @Test("A folder whose auth can't be read has none on its node, and is still where the auth comes from")
    func unreadableAuth() throws {
        let (dataModel, _) = try tree(collection: .none, outer: .inherit, inner: .inherit)
        let context = ModelContext(dataModel.container)
        let row = try #require(context.fetch(FetchDescriptor<FolderModel>()).first { $0.name == "Inner" })
        row.authData = Data("not JSON".utf8)
        try context.save()

        let tree = try CollectionTree(savedIn: dataModel)

        let inner = try #require(tree.node(.folder(row.id)))
        #expect(inner.auth == nil)
        #expect(tree.inheritedAuth(of: .request(request.id)) == .from("Inner"))
    }

}
