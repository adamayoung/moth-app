//  InMemorySecretStoreTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct InMemorySecretStoreTests {

    private let store: any SecretStore = InMemorySecretStore()

    @Test("A saved value is returned by its identifier")
    func returnsASavedValue() async throws {
        try await store.save("s3cret", for: "api-key")

        #expect(try await store.value(for: "api-key") == "s3cret")
    }

    @Test("Saving again replaces the value")
    func replacesAValue() async throws {
        try await store.save("old", for: "api-key")

        try await store.save("new", for: "api-key")

        #expect(try await store.value(for: "api-key") == "new")
    }

    @Test("A missing identifier returns nothing rather than an error")
    func returnsNothingForAMissingIdentifier() async throws {
        #expect(try await store.value(for: "missing") == nil)
    }

    @Test("A removed value is no longer returned")
    func removesAValue() async throws {
        try await store.save("s3cret", for: "api-key")

        try await store.removeValue(for: "api-key")

        #expect(try await store.value(for: "api-key") == nil)
    }

    @Test("Removing a missing identifier does not throw")
    func removesAMissingIdentifier() async {
        await #expect(throws: Never.self) {
            try await store.removeValue(for: "missing")
        }
    }

    @Test("Removing one identifier leaves another")
    func removesOnlyTheNamedValue() async throws {
        try await store.save("first", for: "one")
        try await store.save("second", for: "two")

        try await store.removeValue(for: "one")

        #expect(try await store.value(for: "two") == "second")
    }

}
