//  SecretStore.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

/// Async and nonisolated because a Keychain conformer's `SecItem` calls block their thread.
public nonisolated protocol SecretStore: Sendable {

    func save(_ value: String, for identifier: String) async throws

    func value(for identifier: String) async throws -> String?

    func removeValue(for identifier: String) async throws

}
