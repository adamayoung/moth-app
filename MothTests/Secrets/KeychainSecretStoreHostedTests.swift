//  KeychainSecretStoreHostedTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Security
import Testing

struct KeychainSecretStoreHostedTests {

    private let store = KeychainSecretStore(
        service: "uk.co.adam-young.MothTests.\(UUID().uuidString)",
        mode: .localOnly
    )
    private let identifier = UUID().uuidString

    @Test("A saved value reads back by its identifier")
    func readsASavedValue() async throws {
        try await removingItemAfterwards {
            try await store.save("s3cret", for: identifier)

            #expect(try await store.value(for: identifier) == "s3cret")
        }
    }

    @Test("Saving again replaces the value")
    func replacesAValue() async throws {
        try await removingItemAfterwards {
            try await store.save("old", for: identifier)

            try await store.save("new", for: identifier)

            #expect(try await store.value(for: identifier) == "new")
        }
    }

    @Test("A removed value is no longer returned")
    func removesAValue() async throws {
        try await removingItemAfterwards {
            try await store.save("s3cret", for: identifier)

            try await store.removeValue(for: identifier)

            #expect(try await store.value(for: identifier) == nil)
        }
    }

    @Test("A missing identifier returns nothing rather than an error")
    func returnsNothingForAMissingIdentifier() async throws {
        #expect(try await store.value(for: identifier) == nil)
    }

    @Test("Removing a missing identifier does not throw")
    func removesAMissingIdentifier() async {
        await #expect(throws: Never.self) {
            try await store.removeValue(for: identifier)
        }
    }

    @Test("Saving to an access group the build is not entitled to is an error")
    func unentitledAccessGroupThrows() async {
        let unentitledStore = KeychainSecretStore(
            service: "uk.co.adam-young.MothTests.\(UUID().uuidString)",
            mode: .synchronised(accessGroup: "uk.co.adam-young.MothTests.not-entitled")
        )

        await #expect(throws: KeychainSecretStoreError(operation: .save, status: errSecMissingEntitlement)) {
            try await unentitledStore.save("s3cret", for: identifier)
        }
    }

    private func removingItemAfterwards(_ body: () async throws -> Void) async throws {
        do {
            try await body()
        } catch {
            try? await store.removeValue(for: identifier)
            throw error
        }
        try await store.removeValue(for: identifier)
    }

}
