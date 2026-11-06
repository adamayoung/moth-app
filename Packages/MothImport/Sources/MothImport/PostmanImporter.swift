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

    public func importFile(
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

        try await save(mapper.pendingSecrets)

        return PostmanImportResult(
            content: content,
            imported: mapper.imported,
            skipped: mapper.skipped,
            secrets: mapper.pendingSecrets.map(\.reference)
        )
    }

    private func save(_ secrets: [PendingSecret]) async throws {
        var saved: [SecretReference] = []
        do {
            for secret in secrets {
                try await secretStore.save(secret.value, for: secret.reference.identifier)
                saved.append(secret.reference)
            }
        } catch {
            for reference in saved {
                try? await secretStore.removeValue(for: reference.identifier)
            }
            throw error
        }
    }

}

private nonisolated enum PostmanFile {

    case collection(PostmanCollection)
    case environment(PostmanEnvironment)

    init(decoding data: Data) throws {
        let decoder = JSONDecoder()

        if let collection = try? decoder.decode(PostmanCollection.self, from: data) {
            self = .collection(collection)
        } else if let environment = try? decoder.decode(PostmanEnvironment.self, from: data) {
            self = .environment(environment)
        } else {
            throw PostmanImportError.unrecognisedFile
        }
    }

}
