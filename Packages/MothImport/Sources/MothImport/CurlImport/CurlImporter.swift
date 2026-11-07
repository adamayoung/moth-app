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

    private static var listLocale: Locale {
        Locale(identifier: Bundle.module.preferredLocalizations.first ?? "en-GB")
    }

    public var importedSummary: String {
        String(localized: "CURL_IMPORT_SUMMARY_\(request.name)", bundle: .module)
    }

    public var ignoredSummary: String? {
        guard !ignored.isEmpty else {
            return nil
        }
        let list = ignored.formatted(.list(type: .and).locale(Self.listLocale))
        return String(localized: "CURL_IGNORED_\(list)", bundle: .module)
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

        try await save(mapper.pendingSecrets)
        do {
            try await store(request)
        } catch {
            await remove(secrets)
            throw error
        }
        return CurlImportResult(request: request, ignored: command.ignored, secrets: secrets)
    }

    private func save(_ secrets: [PendingSecret]) async throws {
        var saved: [SecretReference] = []
        do {
            for secret in secrets {
                try await secretStore.save(secret.value, for: secret.reference.identifier)
                saved.append(secret.reference)
            }
        } catch {
            await remove(saved)
            throw error
        }
    }

    private func remove(_ secrets: [SecretReference]) async {
        for reference in secrets {
            try? await secretStore.removeValue(for: reference.identifier)
        }
    }

}
