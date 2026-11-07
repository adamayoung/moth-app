//  CurlImporter.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore

public nonisolated enum CurlImportError: Error, Sendable, Equatable {

    case notACurlCommand

}

public nonisolated struct CurlImportResult: Sendable, Hashable {

    public let request: Request
    public let ignored: [String]
    public let secrets: [SecretReference]

    public var importedSummary: String {
        String(localized: "CURL_IMPORT_SUMMARY_\(request.name)", bundle: .module)
    }

    public var ignoredSummary: String? {
        guard !ignored.isEmpty else {
            return nil
        }
        return String(localized: "CURL_IGNORED_\(ignored.catalogList)", bundle: .module)
    }

}

public nonisolated struct CurlImporter: Sendable {

    private let secretStore: any SecretStore

    public init(secretStore: any SecretStore) {
        self.secretStore = secretStore
    }

    @concurrent
    public func importCommand(
        _ text: String,
        into store: @Sendable (Request) async throws -> Void
    ) async throws -> CurlImportResult {
        let command = try CurlCommand(text)
        var mapper = CurlMapper()
        let request = mapper.request(command)
        let secrets = mapper.pendingSecrets.map(\.reference)

        try await secretStore.save(mapper.pendingSecrets)
        do {
            try await store(request)
        } catch {
            await secretStore.removeValues(of: secrets)
            throw error
        }
        return CurlImportResult(request: request, ignored: command.ignored, secrets: secrets)
    }

}
