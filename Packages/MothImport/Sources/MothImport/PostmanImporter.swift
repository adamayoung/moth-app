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
        existingCollectionNames _: Set<String>,
        existingEnvironmentNames _: Set<String>
    ) async throws -> PostmanImportResult {
        let collection = try JSONDecoder().decode(PostmanCollection.self, from: data)
        var mapper = PostmanMapper()
        let content = PostmanImportContent.collection(mapper.collection(collection))

        for secret in mapper.pendingSecrets {
            try await secretStore.save(secret.value, for: secret.reference.identifier)
        }

        return PostmanImportResult(
            content: content,
            imported: mapper.imported,
            skipped: mapper.skipped,
            secrets: mapper.pendingSecrets.map(\.reference)
        )
    }

}
