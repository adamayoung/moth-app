//  Fixture.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import MothImport
import Testing

enum Fixture {

    /// PostmanKit's test bundle is out of reach from this package, so this reads its licensed files in place.
    private static let directory = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "PostmanKit/Tests/PostmanKitTests/Fixtures")

    static func data(_ path: String) throws -> Data {
        try Data(contentsOf: directory.appending(path: path))
    }

    static func importing(
        _ path: String,
        secretStore: any SecretStore = InMemorySecretStore()
    ) async throws -> PostmanImportResult {
        try await PostmanImporter(secretStore: secretStore).importFile(
            data(path),
            existingCollectionNames: [],
            existingEnvironmentNames: []
        )
    }

    static func collection(_ path: String) async throws -> RequestCollection {
        try #require(await importing(path).collection)
    }

    /// For what no licensed fixture holds. `items` is the JSON of a collection's `item` array.
    static func snippetCollection(items: String, extraKeys: String = "") -> Data {
        Data("""
        {
            "info": {
                "name": "Snippet",
                "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
            },
            \(extraKeys)
            "item": \(items)
        }
        """.utf8)
    }

    static func importingSnippet(
        items: String,
        extraKeys: String = "",
        secretStore: any SecretStore = InMemorySecretStore()
    ) async throws -> PostmanImportResult {
        try await PostmanImporter(secretStore: secretStore).importFile(
            snippetCollection(items: items, extraKeys: extraKeys),
            existingCollectionNames: [],
            existingEnvironmentNames: []
        )
    }

    /// `auth` is the JSON of one request's `auth`.
    static func importingAuth(_ auth: String) async throws -> PostmanImportResult {
        try await importingSnippet(items: #"[{ "name": "a", "request": { "auth": \#(auth) } }]"#)
    }

    static func stored(_ reference: SecretReference?, in store: InMemorySecretStore) async -> String? {
        guard let reference else {
            return nil
        }
        return await store.value(for: reference.identifier)
    }

    /// `request` is the JSON of one item's `request`.
    static func snippetRequest(_ request: String) async throws -> Request {
        let result = try await importingSnippet(items: #"[{ "name": "Snippet", "request": \#(request) }]"#)
        return try #require(result.collection?.requests.first)
    }

}

extension PostmanImportResult {

    var collection: RequestCollection? {
        if case .collection(let collection) = content {
            return collection
        }
        return nil
    }

    var environment: WorkspaceEnvironment? {
        if case .environment(let environment) = content {
            return environment
        }
        return nil
    }

}

extension RequestCollection {

    var requests: [Request] {
        children.requests
    }

    func request(named name: String) throws -> Request {
        try #require(requests.first { $0.name == name })
    }

}

extension [CollectionItem] {

    var requests: [Request] {
        flatMap { item -> [Request] in
            switch item.node {
            case .folder(let folder): folder.children.requests
            case .request(let request): [request]
            }
        }
    }

}

extension CollectionItem {

    var folder: Folder? {
        if case .folder(let folder) = node {
            return folder
        }
        return nil
    }

    var request: Request? {
        if case .request(let request) = node {
            return request
        }
        return nil
    }

}
