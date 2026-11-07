//  PostmanImporter.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import PostmanKit

public nonisolated struct PostmanImporter: Sendable {

    private let secretStore: any SecretStore

    public init(secretStore: any SecretStore) {
        self.secretStore = secretStore
    }

    public func canImport(schema: String) -> Bool {
        PostmanSchema(rawValue: schema) != nil
    }

    @concurrent
    func importFile(
        _ data: Data,
        existingCollectionNames: Set<String>,
        existingEnvironmentNames: Set<String>
    ) async throws -> PostmanImportResult {
        var mapper = PostmanMapper()
        let content: PostmanImportContent = switch try PostmanFile(decoding: data) {
        case .collection(let collection):
            .collection(mapper.collection(collection, avoiding: existingCollectionNames))
        case .environment(let environment):
            .environment(mapper.environment(environment, avoiding: existingEnvironmentNames))
        }

        try await secretStore.save(mapper.pendingSecrets)

        return PostmanImportResult(
            content: content,
            imported: mapper.imported,
            skipped: mapper.skipped,
            secrets: mapper.pendingSecrets.map(\.reference)
        )
    }

    @concurrent
    public func importFile(
        _ data: Data,
        existingCollectionNames: Set<String>,
        existingEnvironmentNames: Set<String>,
        into store: @Sendable (PostmanImportContent) async throws -> Void
    ) async throws -> PostmanImportResult {
        let result = try await importFile(
            data,
            existingCollectionNames: existingCollectionNames,
            existingEnvironmentNames: existingEnvironmentNames
        )
        do {
            try await store(result.content)
        } catch {
            await secretStore.removeValues(of: result.secrets)
            throw error
        }
        return result
    }

}

private nonisolated enum PostmanFile {

    case collection(PostmanCollection)
    case environment(PostmanEnvironment)

    init(decoding data: Data) throws {
        let decoder = JSONDecoder()

        if let collection = try? decoder.decode(PostmanCollection.self, from: data) {
            self = .collection(collection)
        } else if let environment = try? decoder.decode(PostmanEnvironment.self, from: data),
                  environment.isEnvironmentFile {
            self = .environment(environment)
        } else {
            throw PostmanImportError.unrecognisedFile
        }
    }

}

private nonisolated extension PostmanEnvironment {

    /// Only `values` is required on the wire, so a name or a scope is what tells this from any other JSON.
    var isEnvironmentFile: Bool {
        (name != nil || scope != nil) && (scope ?? "environment") == "environment"
    }

}
