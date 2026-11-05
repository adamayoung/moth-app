//  InMemorySecretStoreTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct InMemorySecretStoreTests {

    private let store = InMemorySecretStore()

    @Test("A saved value is returned by its identifier")
    func returnsASavedValue() {
        store.save("s3cret", for: "api-key")

        #expect(store.value(for: "api-key") == "s3cret")
    }

    @Test("Saving again replaces the value")
    func replacesAValue() {
        store.save("old", for: "api-key")

        store.save("new", for: "api-key")

        #expect(store.value(for: "api-key") == "new")
    }

    @Test("A missing identifier returns nothing rather than an error")
    func returnsNothingForAMissingIdentifier() throws {
        let store: any SecretStore = store

        #expect(try store.value(for: "missing") == nil)
    }

    @Test("A removed value is no longer returned")
    func removesAValue() {
        store.save("s3cret", for: "api-key")

        store.removeValue(for: "api-key")

        #expect(store.value(for: "api-key") == nil)
    }

    @Test("Removing a missing identifier does not throw")
    func removesAMissingIdentifier() {
        let store: any SecretStore = store

        #expect(throws: Never.self) {
            try store.removeValue(for: "missing")
        }
    }

    @Test("Removing one identifier leaves another")
    func removesOnlyTheNamedValue() {
        store.save("first", for: "one")
        store.save("second", for: "two")

        store.removeValue(for: "one")

        #expect(store.value(for: "two") == "second")
    }

}
