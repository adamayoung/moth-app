//  FailingSecretStore.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore

nonisolated struct FailingSecretStore: SecretStore {

    struct Failure: Error {}

    func save(_ value: String, for identifier: String) async throws {
        throw Failure()
    }

    func value(for identifier: String) async throws -> String? {
        throw Failure()
    }

    func removeValue(for identifier: String) async throws {
        throw Failure()
    }

}
