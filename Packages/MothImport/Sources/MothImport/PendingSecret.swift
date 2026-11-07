//  PendingSecret.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore

nonisolated struct PendingSecret: Sendable {

    let reference: SecretReference
    let value: String

}

nonisolated extension SecretStore {

    /// All or nothing: a failed save removes those already saved.
    func save(_ secrets: [PendingSecret]) async throws {
        var saved: [SecretReference] = []
        do {
            for secret in secrets {
                try await save(secret.value, for: secret.reference.identifier)
                saved.append(secret.reference)
            }
        } catch {
            await removeValues(of: saved)
            throw error
        }
    }

    func removeValues(of secrets: [SecretReference]) async {
        for reference in secrets {
            try? await removeValue(for: reference.identifier)
        }
    }

}
