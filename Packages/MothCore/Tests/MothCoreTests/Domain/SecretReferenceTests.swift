//  SecretReferenceTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct SecretReferenceTests {

    @Test("A reference keeps the identifier it was given")
    func keepsItsIdentifier() {
        #expect(SecretReference(identifier: "api-key").identifier == "api-key")
    }

    @Test("Each new reference has its own identifier")
    func newReferencesAreUnique() {
        #expect(SecretReference() != SecretReference())
    }

    @Test("A reference's identifier finds its value in a secret store")
    func findsItsValueInASecretStore() async {
        let store = InMemorySecretStore()
        let reference = SecretReference()

        await store.save("s3cret", for: reference.identifier)

        #expect(await store.value(for: reference.identifier) == "s3cret")
    }

}
