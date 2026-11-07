//  AuthInheritanceTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct AuthInheritanceTests {

    private let token = SecretReference(identifier: "token")
    private let password = SecretReference(identifier: "password")
    private let request = Request(name: "Request")

    private var bearer: Auth {
        .bearer(BearerAuth(token: token))
    }

    private var basic: Auth {
        .basic(BasicAuth(username: "user", password: password))
    }

    @Test("A request that sets auth keeps it")
    func ownAuth() {
        let own = Request(name: "Request", auth: basic)
        let collection = RequestCollection(name: "API", auth: bearer, children: [Self.item(.request(own))])

        #expect(collection.effectiveAuth(of: own) == basic)
    }

    @Test("A request that sets no auth stops the walk")
    func ownNoAuth() {
        let own = Request(name: "Request", auth: .none)
        let collection = RequestCollection(name: "API", auth: bearer, children: [Self.item(.request(own))])

        #expect(collection.effectiveAuth(of: own) == Auth.none)
    }

    @Test("Inherit stops at the nearest folder that sets auth")
    func nearestFolder() {
        let collection = nested(collectionAuth: .inherit, folderAuths: [basic, bearer])

        #expect(collection.effectiveAuth(of: request) == bearer)
    }

    @Test("Inherit passes through folders that inherit, to the collection")
    func throughFoldersToCollection() {
        let collection = nested(collectionAuth: bearer, folderAuths: [.inherit, .inherit])

        #expect(collection.effectiveAuth(of: request) == bearer)
    }

    @Test("A folder that sets no auth stops the walk")
    func folderNoneStops() {
        let collection = nested(collectionAuth: bearer, folderAuths: [.none, .inherit])

        #expect(collection.effectiveAuth(of: request) == Auth.none)
    }

    @Test("With nothing to inherit, there is no auth")
    func nothingToInherit() {
        let collection = nested(collectionAuth: .inherit, folderAuths: [.inherit])

        #expect(collection.effectiveAuth(of: request) == Auth.none)
    }

    @Test("A request in a later branch finds its own folders")
    func laterBranch() {
        let sibling = Folder(name: "Sibling", auth: basic, children: [Self.item(.request(Request(name: "Other")))])
        let owner = Folder(name: "Owner", auth: bearer, children: [Self.item(.request(request))])
        let collection = RequestCollection(
            name: "API",
            children: [
                CollectionItem(sortOrder: 0, node: .folder(sibling)),
                CollectionItem(sortOrder: 1, node: .folder(owner))
            ]
        )

        #expect(collection.effectiveAuth(of: request) == bearer)
    }

    @Test("A request outside the tree inherits nothing, so no credential reaches it by accident")
    func requestOutsideTheTree() {
        let collection = nested(collectionAuth: bearer, folderAuths: [.none])

        #expect(collection.effectiveAuth(of: Request(name: "Elsewhere")) == Auth.none)
    }

    @Test("An inherited credential reaches the header through the resolver and the builder")
    func inheritedCredentialIsSent() async throws {
        let store = InMemorySecretStore()
        await store.save("abc", for: token.identifier)
        let collection = nested(collectionAuth: bearer, folderAuths: [.inherit])
        var effective = Request(id: request.id, name: "Request", urlTemplate: "https://example.com")
        effective.auth = collection.effectiveAuth(of: effective)

        let resolved = try await VariableResolver(secretStore: store).resolve(
            effective,
            collection: collection.variables,
            environment: [],
            globals: []
        )
        let built = try await RequestBuilder().build(resolved)

        #expect(built.urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
    }

    @Test("An API key inherited from a folder or a collection goes out", arguments: [
        (true, APIKeyLocation.header),
        (false, .header),
        (true, .query),
        (false, .query)
    ])
    func inheritedAPIKeyIsSent(fromFolder: Bool, location: APIKeyLocation) async throws {
        let store = InMemorySecretStore()
        await store.save("abc", for: token.identifier)
        let apiKey = Auth.apiKey(APIKeyAuth(name: "X-Key", value: token, location: location))
        let collection = nested(
            collectionAuth: fromFolder ? bearer : apiKey,
            folderAuths: [.inherit, fromFolder ? apiKey : .inherit]
        )
        var effective = Request(id: request.id, name: "Request", urlTemplate: "https://example.com")
        effective.auth = collection.effectiveAuth(of: effective)

        let resolved = try await VariableResolver(secretStore: store).resolve(
            effective,
            collection: collection.variables,
            environment: [],
            globals: []
        )
        let built = try await RequestBuilder().build(resolved)

        #expect(effective.auth == apiKey)
        switch location {
        case .header:
            #expect(built.urlRequest.value(forHTTPHeaderField: "X-Key") == "abc")
        case .query:
            #expect(built.urlRequest.url?.query == "X-Key=abc")
        }
    }

    private func nested(collectionAuth: Auth, folderAuths outermostFirst: [Auth]) -> RequestCollection {
        let children = outermostFirst.reversed().reduce([Self.item(.request(request))]) { children, auth in
            [Self.item(.folder(Folder(name: "Folder", auth: auth, children: children)))]
        }

        return RequestCollection(name: "API", auth: collectionAuth, children: children)
    }

    private static func item(_ node: CollectionNode) -> CollectionItem {
        CollectionItem(sortOrder: 0, node: node)
    }

}
