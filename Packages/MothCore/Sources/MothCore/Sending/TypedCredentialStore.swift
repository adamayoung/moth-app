//  TypedCredentialStore.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

/// Answers what the editor holds first, so an unsaved credential sends without reaching the Keychain.
nonisolated struct TypedCredentialStore: SecretStore {

    private let typed: [String: String]
    private let stored: any SecretStore

    init(typed: [CredentialWrite], stored: any SecretStore) {
        self.typed = Dictionary(typed.map { ($0.reference.identifier, $0.value) }) { _, last in last }
        self.stored = stored
    }

    func save(_ value: String, for identifier: String) async throws {
        try await stored.save(value, for: identifier)
    }

    func value(for identifier: String) async throws -> String? {
        if let value = typed[identifier] {
            return value
        }
        return try await stored.value(for: identifier)
    }

    func removeValue(for identifier: String) async throws {
        try await stored.removeValue(for: identifier)
    }

}
